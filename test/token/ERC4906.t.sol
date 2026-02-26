// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC4906} from "../../src/token/ERC4906/ERC4906.sol";
import {IERC4906} from "../../src/token/ERC4906/IERC4906.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC4906 is ERC4906 {
    string private _baseURI_;

    constructor() ERC721("MetaNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function setBaseURI(string memory newURI) external {
        _baseURI_ = newURI;
        _emitBatchMetadataUpdate(0, type(uint256).max);
    }

    function refreshMetadata(uint256 tokenId) external {
        _emitMetadataUpdate(tokenId);
    }

    function refreshBatch(uint256 from, uint256 to) external {
        _emitBatchMetadataUpdate(from, to);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseURI_;
    }
}

contract ERC4906Test is Test {
    MockERC4906 internal nft;
    address internal alice = makeAddr("alice");

    function setUp() public {
        nft = new MockERC4906();
        nft.mint(alice, 1);
        nft.mint(alice, 2);
        nft.mint(alice, 3);
    }

    function test_supportsInterface_ERC4906() public view {
        assertTrue(nft.supportsInterface(bytes4(0x49064906)));
    }

    function test_supportsInterface_ERC721() public view {
        assertTrue(nft.supportsInterface(bytes4(0x80ac58cd)));
    }

    function test_metadataUpdate_single() public {
        vm.expectEmit(true, true, true, true);
        emit IERC4906.MetadataUpdate(1);
        nft.refreshMetadata(1);
    }

    function test_batchMetadataUpdate() public {
        vm.expectEmit(true, true, true, true);
        emit IERC4906.BatchMetadataUpdate(1, 100);
        nft.refreshBatch(1, 100);
    }

    function test_setBaseURI_emitsBatchUpdate() public {
        vm.expectEmit(true, true, true, true);
        emit IERC4906.BatchMetadataUpdate(0, type(uint256).max);
        nft.setBaseURI("ipfs://newbase/");
    }

    function testFuzz_metadataUpdate(uint256 tokenId) public {
        vm.expectEmit(true, true, true, true);
        emit IERC4906.MetadataUpdate(tokenId);
        nft.refreshMetadata(tokenId);
    }

    function testFuzz_batchMetadataUpdate(uint256 from, uint256 to) public {
        vm.expectEmit(true, true, true, true);
        emit IERC4906.BatchMetadataUpdate(from, to);
        nft.refreshBatch(from, to);
    }
}
