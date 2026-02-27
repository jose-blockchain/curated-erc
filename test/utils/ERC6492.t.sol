// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC6492} from "../../src/utils/cryptography/ERC6492.sol";
import {IERC1271} from "../../src/utils/cryptography/IERC1271.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// --- Helpers ---

contract MockWallet is IERC1271 {
    address public owner;

    constructor(address owner_) {
        owner = owner_;
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4) {
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(hash, signature);
        if (err == ECDSA.RecoverError.NoError && recovered == owner) {
            return 0x1626ba7e;
        }
        return 0xffffffff;
    }
}

contract WalletFactory {
    function deploy(address owner, bytes32 salt) external returns (address) {
        return address(new MockWallet{salt: salt}(owner));
    }

    function getAddress(address owner, bytes32 salt) external view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(abi.encodePacked(type(MockWallet).creationCode, abi.encode(owner)))
            )
        );
        return address(uint160(uint256(hash)));
    }
}

contract RejectingWallet is IERC1271 {
    function isValidSignature(bytes32, bytes memory) external pure returns (bytes4) {
        return 0xffffffff;
    }
}

contract RevertingWallet is IERC1271 {
    function isValidSignature(bytes32, bytes memory) external pure returns (bytes4) {
        revert("not supported");
    }
}

contract UpgradeableWallet is IERC1271 {
    address public owner;

    function setOwner(address newOwner) external {
        owner = newOwner;
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4) {
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(hash, signature);
        if (err == ECDSA.RecoverError.NoError && recovered == owner) {
            return 0x1626ba7e;
        }
        return 0xffffffff;
    }
}

/// @dev Wrapper to call library functions
contract ERC6492Validator {
    function isValidSig(address signer, bytes32 hash, bytes calldata signature) external returns (bool) {
        return ERC6492.isValidSig(signer, hash, signature);
    }
}

// --- Tests ---

contract ERC6492Test is Test {
    ERC6492Validator internal validator;
    WalletFactory internal factory;

    uint256 internal signerKey = 0xA11CE;
    address internal signer;
    bytes32 internal salt = bytes32(uint256(1));

    function setUp() public {
        validator = new ERC6492Validator();
        factory = new WalletFactory();
        signer = vm.addr(signerKey);
    }

    // --- EOA signatures ---

    function test_eoaSignature_valid() public {
        bytes32 hash = keccak256("test");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);

        assertTrue(validator.isValidSig(signer, hash, sig));
    }

    function test_eoaSignature_invalid_wrongSigner() public {
        bytes32 hash = keccak256("test");
        uint256 wrongKey = 0xB0B;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);

        assertFalse(validator.isValidSig(signer, hash, sig));
    }

    function test_eoaSignature_invalid_badLength() public {
        bytes32 hash = keccak256("test");
        assertFalse(validator.isValidSig(signer, hash, hex"deadbeef"));
    }

    // --- ERC-1271 (deployed contract) ---

    function test_erc1271_deployed_valid() public {
        MockWallet wallet = new MockWallet(signer);
        bytes32 hash = keccak256("test");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);

        assertTrue(validator.isValidSig(address(wallet), hash, sig));
    }

    function test_erc1271_deployed_invalid() public {
        RejectingWallet wallet = new RejectingWallet();
        bytes32 hash = keccak256("test");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);

        assertFalse(validator.isValidSig(address(wallet), hash, sig));
    }

    // --- ERC-6492 (pre-deploy) ---

    function test_erc6492_predeploy_valid() public {
        address predicted = factory.getAddress(signer, salt);
        assertTrue(predicted.code.length == 0);

        bytes32 hash = keccak256("test");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash);
        bytes memory originalSig = abi.encodePacked(r, s, v);

        bytes memory factoryCalldata = abi.encodeCall(WalletFactory.deploy, (signer, salt));
        bytes memory wrappedSig = abi.encodePacked(
            abi.encode(address(factory), factoryCalldata, originalSig), ERC6492.ERC6492_DETECTION_SUFFIX
        );

        assertTrue(validator.isValidSig(predicted, hash, wrappedSig));
        assertTrue(predicted.code.length > 0);
    }

    function test_erc6492_predeploy_invalid_wrongSig() public {
        address predicted = factory.getAddress(signer, salt);

        bytes32 hash = keccak256("test");
        uint256 wrongKey = 0xB0B;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongKey, hash);
        bytes memory originalSig = abi.encodePacked(r, s, v);

        bytes memory factoryCalldata = abi.encodeCall(WalletFactory.deploy, (signer, salt));
        bytes memory wrappedSig = abi.encodePacked(
            abi.encode(address(factory), factoryCalldata, originalSig), ERC6492.ERC6492_DETECTION_SUFFIX
        );

        assertFalse(validator.isValidSig(predicted, hash, wrappedSig));
    }

    function test_erc6492_predeploy_revert_deployFailed() public {
        address predicted = factory.getAddress(signer, salt);

        bytes32 hash = keccak256("test");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash);
        bytes memory originalSig = abi.encodePacked(r, s, v);

        // Bad factory calldata that will fail
        bytes memory wrappedSig = abi.encodePacked(
            abi.encode(address(factory), hex"deadbeef", originalSig), ERC6492.ERC6492_DETECTION_SUFFIX
        );

        vm.expectRevert(ERC6492.ERC6492DeployFailed.selector);
        validator.isValidSig(predicted, hash, wrappedSig);
    }

    function test_erc6492_alreadyDeployed_withSuffix() public {
        // Deploy the wallet first
        address wallet = factory.deploy(signer, salt);
        assertTrue(wallet.code.length > 0);

        bytes32 hash = keccak256("test");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash);
        bytes memory originalSig = abi.encodePacked(r, s, v);

        // Wrap with ERC-6492 suffix even though already deployed
        bytes memory factoryCalldata = abi.encodeCall(WalletFactory.deploy, (signer, salt));
        bytes memory wrappedSig = abi.encodePacked(
            abi.encode(address(factory), factoryCalldata, originalSig), ERC6492.ERC6492_DETECTION_SUFFIX
        );

        assertTrue(validator.isValidSig(wallet, hash, wrappedSig));
    }

    // --- ERC-6492 wrapped + deployed, factory "prepare" retry path ---

    function test_erc6492_deployed_prepareRetry() public {
        // Deploy the wallet in an initial state that rejects all sigs
        UpgradeableWallet wallet = new UpgradeableWallet();
        assertTrue(address(wallet).code.length > 0);

        bytes32 hash = keccak256("test");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash);
        bytes memory originalSig = abi.encodePacked(r, s, v);

        // Factory calldata that upgrades the wallet to accept our signer
        bytes memory factoryCalldata = abi.encodeCall(UpgradeableWallet.setOwner, (signer));

        bytes memory wrappedSig = abi.encodePacked(
            abi.encode(address(wallet), factoryCalldata, originalSig), ERC6492.ERC6492_DETECTION_SUFFIX
        );

        // First ERC-1271 check fails (owner is address(0)), then prepare sets owner, retry passes
        assertTrue(validator.isValidSig(address(wallet), hash, wrappedSig));
    }

    // --- EOA with empty signature ---

    function test_eoaSignature_empty() public {
        bytes32 hash = keccak256("test");
        assertFalse(validator.isValidSig(signer, hash, ""));
    }

    // --- ERC-1271 deployed contract that reverts ---

    function test_erc1271_deployed_contractReverts() public {
        RevertingWallet rw = new RevertingWallet();
        bytes32 hash = keccak256("test");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);

        assertFalse(validator.isValidSig(address(rw), hash, sig));
    }

    // --- Fuzz ---

    function testFuzz_eoaSignature(bytes32 hash) public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);
        assertTrue(validator.isValidSig(signer, hash, sig));
    }

    function testFuzz_erc1271_deployed(bytes32 hash) public {
        MockWallet wallet = new MockWallet(signer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, hash);
        bytes memory sig = abi.encodePacked(r, s, v);
        assertTrue(validator.isValidSig(address(wallet), hash, sig));
    }
}
