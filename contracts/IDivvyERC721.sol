// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IDivvyERC721 is IERC721 {
    function divvyMint(address to) external returns (uint256);
}
