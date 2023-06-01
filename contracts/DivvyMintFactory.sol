// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DivvyMintController.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract DivvyMintFactory is AccessControl {
    mapping(address => uint256) public nftIds; // nftAddress => nftId
    mapping(uint256 => address) public nftControllers; // nftId => controllerAddress
    address[] public paymentTokens;

    uint256 public lastNFTId = 0;
    address controllersAdmin;

    event ListNFT(address collection, uint256 nftId, address controller);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        controllersAdmin = msg.sender;
    }

    function listNFT(
        address nftAddress,
        uint256 sharePrice,
        uint256 sharesCount,
        address paymentToken
    ) external {
        require(
            paymentTokenExists(paymentToken) || paymentToken == address(0),
            "Invalid payment token!"
        );
        require(sharePrice > 0, "sharePrice <= 0");
        require(sharesCount > 0, "sharesCount <= 0");
        require(nftIds[nftAddress] == 0, "Already listed!");

        uint256 nftId = ++lastNFTId;

        DivvyMintController NFTController = new DivvyMintController(
            controllersAdmin,
            nftAddress,
            sharePrice,
            sharesCount,
            paymentToken
        );
        nftControllers[nftId] = address(NFTController);
        nftIds[nftAddress] = nftId;

        NFTController.transferOwnership(msg.sender);

        emit ListNFT(nftAddress, nftId, address(NFTController));
    }

    function addNFT(
        address nft,
        address controller
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256 nftId) {
        require(nftIds[nft] == 0, "Already listed!");

        nftId = ++lastNFTId;

        nftControllers[nftId] = controller;
        nftIds[nft] = nftId;

        emit ListNFT(nft, nftId, controller);
    }

    function addPaymentToken(
        address token
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!paymentTokenExists(token), "Already exist");
        paymentTokens.push(token);
    }

    function removePaymentToken(
        address token
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            if (paymentTokens[i] == token) {
                delete paymentTokens[i];
            }
        }
    }

    function setControllersAdmin(
        address admin
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(admin != address(0), "!admin");
        controllersAdmin = admin;
    }

    function paymentTokenExists(address token) public view returns (bool) {
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            if (paymentTokens[i] == token) {
                return true;
            }
        }
        return false;
    }
}
