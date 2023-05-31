// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IDivvyERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract DivvyPurchaseController is AccessControl, IERC721Receiver, Pausable {
    bytes4 public constant _ERC721_RECEIVED = 0x150b7a02;

    mapping(uint256 => offer) public offers; // offerId => offer
    uint256 public currentOfferId = 0;

    address public collection;
    uint256 public tokenId;
    uint256 public sharePrice;
    uint256 public sharesCount;
    address public paymentToken; // TODO: Support multiple payment tokens
    bool public isListed = true;

    event Purchase(uint256 offerId);

    struct offer {
        uint256 purchasedShares;
        PurchaseShare[] shares;
        bool isDone;
        bool exists;
    }

    struct PurchaseShare {
        address stakeholder;
        uint256 amount;
        uint256 price; // Each share can has a different price
    }

    constructor(
        address _admin,
        address _collection,
        uint256 _tokenId,
        uint256 _sharePrice,
        uint256 _sharesCount,
        address _paymentToken
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        collection = _collection;
        tokenId = _tokenId;
        sharePrice = _sharePrice;
        sharesCount = _sharesCount;
        paymentToken = _paymentToken;
        newOffer();
    }

    function setSharePrice(
        uint256 price
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(price > 0, "sharePrice <= 0");
        sharePrice = price;
    }

    function setSharesCount(
        uint256 count
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(count > 0, "sharesCount <= 0");
        require(
            count > offers[currentOfferId].purchasedShares,
            "sharesCount can not be less than or equals purchasedShares"
        );
        sharesCount = count;
    }

    function newOffer() private {
        uint256 offerId = ++currentOfferId;

        offer storage _newOffer = offers[offerId];

        _newOffer.purchasedShares = 0;
        _newOffer.isDone = false;
        _newOffer.exists = true;
    }

    function addShare(uint256 amount) external payable whenNotPaused {
        require(isListed, "!isListed");
        require(offers[currentOfferId].exists, "!offer");

        offer storage _offer = offers[currentOfferId];

        require(!_offer.isDone, "It's already done!");
        require(
            amount > 0 && amount <= (sharesCount - _offer.purchasedShares),
            "Invalid share amount!"
        );

        uint256 shareValue = amount * sharePrice;

        if (paymentToken == address(0)) {
            require(msg.value == shareValue, "!msg.value");
        } else {
            IERC20 token = IERC20(paymentToken);
            token.transferFrom(msg.sender, address(this), shareValue);
        }

        _offer.shares.push(
            PurchaseShare({
                stakeholder: msg.sender,
                amount: amount,
                price: sharePrice
            })
        );
        _offer.purchasedShares += amount;

        if (_offer.purchasedShares == sharesCount) {
            purchaseNFT();
        }
    }

    function deleteShare(
        uint256 offerId,
        uint256 index
    ) external whenNotPaused {
        require(offers[offerId].exists, "!offer");

        offer storage _offer = offers[offerId];

        require(index >= 0 && index < _offer.shares.length, "Invalid index!");

        PurchaseShare memory share = _offer.shares[index];
        require(
            !_offer.isDone && (msg.sender == share.stakeholder),
            "Permission denied!"
        );

        _offer.purchasedShares -= share.amount;

        // Delete the share from the shares list
        for (uint256 i = index; i < _offer.shares.length - 1; i++) {
            _offer.shares[i] = _offer.shares[i + 1];
        }
        _offer.shares.pop();

        uint256 shareValue = share.amount * share.price;

        if (paymentToken == address(0)) {
            payable(msg.sender).transfer(shareValue);
        } else {
            IERC20(paymentToken).transfer(msg.sender, shareValue);
        }
    }

    function purchaseNFT() private {
        offer storage _offer = offers[currentOfferId];

        IDivvyERC721 nft = IDivvyERC721(collection);

        address owner = nft.ownerOf(tokenId);
        nft.safeTransferFrom(owner, address(this), tokenId);

        _offer.isDone = true;
        isListed = false;

        uint256 price = 0;

        for (uint256 i = 0; i < _offer.shares.length; i++) {
            PurchaseShare memory share = _offer.shares[i];
            price += (share.amount * share.price);
        }

        if (paymentToken == address(0)) {
            payable(owner).transfer(price);
        } else {
            IERC20(paymentToken).transfer(owner, price);
        }

        emit Purchase(currentOfferId);
    }

    function relist() external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        isListed = true;
        newOffer();
    }

    function unlist() external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        isListed = false;
    }

    function getStakeholders(
        uint256 offerId
    ) public view returns (address[] memory stakeholders) {
        offer memory _offer = offers[offerId];

        stakeholders = new address[](_offer.shares.length);
        for (uint256 i = 0; i < _offer.shares.length; i++) {
            stakeholders[i] = _offer.shares[i].stakeholder;
        }
    }

    function getShare(
        uint256 offerId,
        uint256 index
    ) public view returns (address stakeholder, uint256 amount, uint256 price) {
        offer memory _offer = offers[offerId];

        stakeholder = _offer.shares[index].stakeholder;
        amount = _offer.shares[index].amount;
        price = _offer.shares[index].price;
    }

    function transferToken(
        address to
    ) public onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        IDivvyERC721 nft = IDivvyERC721(collection);
        nft.safeTransferFrom(address(this), to, tokenId);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public pure override returns (bytes4) {
        return _ERC721_RECEIVED;
    }
}
