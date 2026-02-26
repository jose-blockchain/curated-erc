// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC3156FlashLender} from "../../src/finance/ERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from "../../src/finance/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "../../src/finance/IERC3156FlashLender.sol";

// --- Helpers ---

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockLender is ERC3156FlashLender {
    uint256 private _feeBps;

    constructor(uint256 feeBps_) {
        _feeBps = feeBps_;
    }

    function _flashFee(address, uint256 amount) internal view override returns (uint256) {
        return (amount * _feeBps) / 10_000;
    }
}

contract GoodBorrower is IERC3156FlashBorrower {
    function onFlashLoan(
        address,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata
    ) external override returns (bytes32) {
        IERC20(token).approve(msg.sender, amount + fee);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}

contract BadBorrowerWrongReturn is IERC3156FlashBorrower {
    function onFlashLoan(address, address token, uint256 amount, uint256 fee, bytes calldata)
        external
        override
        returns (bytes32)
    {
        IERC20(token).approve(msg.sender, amount + fee);
        return keccak256("wrong");
    }
}

contract BadBorrowerNoRepay is IERC3156FlashBorrower {
    function onFlashLoan(address, address, uint256, uint256, bytes calldata) external pure override returns (bytes32) {
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}

contract ReentrantBorrower is IERC3156FlashBorrower {
    function onFlashLoan(
        address,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata
    ) external override returns (bytes32) {
        IERC20(token).approve(msg.sender, amount + fee);
        IERC3156FlashLender(msg.sender).flashLoan(this, token, amount, "");
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}

contract MockLenderWithFeeReceiver is ERC3156FlashLender {
    uint256 private _feeBps;
    address private _feeRecipient;

    constructor(uint256 feeBps_, address feeRecipient_) {
        _feeBps = feeBps_;
        _feeRecipient = feeRecipient_;
    }

    function _flashFee(address, uint256 amount) internal view override returns (uint256) {
        return (amount * _feeBps) / 10_000;
    }

    function _flashFeeReceiver() internal view override returns (address) {
        return _feeRecipient;
    }
}

// --- Tests ---

contract ERC3156FlashLenderTest is Test {
    MockToken internal token;
    MockLender internal lender;
    GoodBorrower internal borrower;
    BadBorrowerWrongReturn internal badReturnBorrower;
    BadBorrowerNoRepay internal noRepayBorrower;
    ReentrantBorrower internal reentrantBorrower;

    uint256 internal constant POOL = 1_000_000e18;
    uint256 internal constant FEE_BPS = 10; // 0.1%

    function setUp() public {
        token = new MockToken();
        lender = new MockLender(FEE_BPS);
        borrower = new GoodBorrower();
        badReturnBorrower = new BadBorrowerWrongReturn();
        noRepayBorrower = new BadBorrowerNoRepay();
        reentrantBorrower = new ReentrantBorrower();

        token.mint(address(lender), POOL);
    }

    // --- maxFlashLoan ---

    function test_maxFlashLoan() public view {
        assertEq(lender.maxFlashLoan(address(token)), POOL);
    }

    function test_maxFlashLoan_unsupportedToken() public view {
        assertEq(lender.maxFlashLoan(address(0xdead)), 0);
    }

    // --- flashFee ---

    function test_flashFee() public view {
        uint256 amount = 100_000e18;
        uint256 expected = (amount * FEE_BPS) / 10_000;
        assertEq(lender.flashFee(address(token), amount), expected);
    }

    // --- flashLoan success ---

    function test_flashLoan_success() public {
        uint256 amount = 100_000e18;
        uint256 fee = lender.flashFee(address(token), amount);

        // Give borrower enough to pay the fee
        token.mint(address(borrower), fee);

        assertTrue(lender.flashLoan(borrower, address(token), amount, ""));

        // Lender should have original pool + fee
        assertEq(token.balanceOf(address(lender)), POOL + fee);
        assertEq(token.balanceOf(address(borrower)), 0);
    }

    function test_flashLoan_zeroFee() public {
        MockLender zeroFeeLender = new MockLender(0);
        token.mint(address(zeroFeeLender), POOL);

        uint256 amount = 50_000e18;
        assertTrue(zeroFeeLender.flashLoan(borrower, address(token), amount, ""));
        assertEq(token.balanceOf(address(zeroFeeLender)), POOL);
    }

    // --- flashLoan failures ---

    function test_flashLoan_revert_exceedsMax() public {
        uint256 tooMuch = POOL + 1;
        vm.expectRevert(abi.encodeWithSelector(ERC3156FlashLender.ERC3156ExceededMaxLoan.selector, POOL));
        lender.flashLoan(borrower, address(token), tooMuch, "");
    }

    function test_flashLoan_revert_badCallback() public {
        uint256 amount = 1_000e18;
        uint256 fee = lender.flashFee(address(token), amount);
        token.mint(address(badReturnBorrower), fee);

        vm.expectRevert(ERC3156FlashLender.ERC3156CallbackFailed.selector);
        lender.flashLoan(badReturnBorrower, address(token), amount, "");
    }

    function test_flashLoan_revert_noRepay() public {
        uint256 amount = 1_000e18;
        vm.expectRevert();
        lender.flashLoan(noRepayBorrower, address(token), amount, "");
    }

    // --- Zero amount flash loan ---

    function test_flashLoan_zeroAmount() public {
        assertTrue(lender.flashLoan(borrower, address(token), 0, ""));
        assertEq(token.balanceOf(address(lender)), POOL);
    }

    // --- flashFee revert for unsupported token ---

    function test_flashFee_revert_unsupportedToken() public {
        vm.expectRevert(abi.encodeWithSelector(ERC3156FlashLender.ERC3156UnsupportedToken.selector, address(0xdead)));
        lender.flashFee(address(0xdead), 1000);
    }

    // --- Flash loan with separate fee receiver ---

    function test_flashLoan_withFeeReceiver() public {
        address feeRecipient = makeAddr("feeRecipient");
        MockLenderWithFeeReceiver feeReceiverLender = new MockLenderWithFeeReceiver(FEE_BPS, feeRecipient);
        token.mint(address(feeReceiverLender), POOL);

        uint256 amount = 100_000e18;
        uint256 fee = feeReceiverLender.flashFee(address(token), amount);
        token.mint(address(borrower), fee);

        feeReceiverLender.flashLoan(borrower, address(token), amount, "");
        assertEq(token.balanceOf(address(feeReceiverLender)), POOL);
        assertEq(token.balanceOf(feeRecipient), fee);
    }

    // --- Reentrancy ---

    function test_flashLoan_revert_reentrancy() public {
        uint256 amount = 1_000e18;
        uint256 fee = lender.flashFee(address(token), amount);
        token.mint(address(reentrantBorrower), fee * 2);

        vm.expectRevert();
        lender.flashLoan(reentrantBorrower, address(token), amount, "");
    }

    // --- maxFlashLoan returns 0 for address(0) ---

    function test_maxFlashLoan_addressZero() public view {
        assertEq(lender.maxFlashLoan(address(0)), 0);
    }

    // --- Fuzz ---

    function testFuzz_flashLoan(uint256 amount) public {
        amount = bound(amount, 1, POOL);
        uint256 fee = lender.flashFee(address(token), amount);
        token.mint(address(borrower), fee);

        lender.flashLoan(borrower, address(token), amount, "");
        assertEq(token.balanceOf(address(lender)), POOL + fee);
    }

    function testFuzz_flashFee(uint256 amount) public view {
        amount = bound(amount, 0, type(uint128).max);
        uint256 expected = (amount * FEE_BPS) / 10_000;
        assertEq(lender.flashFee(address(token), amount), expected);
    }
}
