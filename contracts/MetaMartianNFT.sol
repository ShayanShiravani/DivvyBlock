// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MetaMartianNFT is ERC721Enumerable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string public _baseTokenURI;

    constructor() ERC721("Meta Martian NFT", "MMN") {
        _baseTokenURI = "https://mmac-meta-martian.communitynftproject.io/";
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function tokensOfOwner(
        address _owner
    ) external view returns (uint256[] memory) {
        uint tokenCount = balanceOf(_owner);
        uint256[] memory tokensIds = new uint256[](tokenCount);
        for (uint i = 0; i < tokenCount; i++) {
            tokensIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensIds;
    }

    function mint(address to, uint256 id) public onlyRole(MINTER_ROLE) {
        _beforeMint(to, id);
        _mint(to, id);
    }

    function divvyMint(
        address to
    ) public onlyRole(MINTER_ROLE) returns (uint256 tokenId) {
        tokenId = totalSupply() + 1;
        mint(to, tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721Enumerable, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeMint(address to, uint256 id) internal virtual {}
}
