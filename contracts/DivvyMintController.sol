// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IDivvyERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract DivvyMintController is
    AccessControl,
    Ownable,
    IERC721Receiver,
    Pausable
{
    bytes4 public constant _ERC721_RECEIVED = 0x150b7a02;

    mapping(uint256 => MintRequest) public mintRequests;
    uint256 public currentRequestId = 0;

    address public addr;
    uint256 public sharePrice;
    uint256 public sharesCount;
    address public paymentToken; // TODO: Support multiple payment tokens
    uint256 public balance = 0;

    event Mint(uint256 requestId, uint256 tokenId);

    struct MintRequest {
        uint256 purchasedShares;
        MintShare[] shares;
        uint256 tokenId;
        bool isMinted;
        bool exists; // whether a requestId exists
    }

    struct MintShare {
        address stakeholder;
        uint256 amount;
        uint256 price; // Each share can has a different price
    }

    constructor(
        address _admin,
        address _addr,
        uint256 _sharePrice,
        uint256 _sharesCount,
        address _paymentToken
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        addr = _addr;
        sharePrice = _sharePrice;
        sharesCount = _sharesCount;
        paymentToken = _paymentToken;
        newMintRequest();
    }

    function setSharePrice(uint256 price) external onlyOwner {
        require(price > 0, "sharePrice <= 0");
        sharePrice = price;
    }

    function changeSharesCount(uint256 count) external onlyOwner {
        require(count > 0, "sharesCount <= 0");
        sharesCount = count;
    }

    function newMintRequest() private {
        uint256 requestId = ++currentRequestId;

        MintRequest storage mintRequest = mintRequests[requestId];

        mintRequest.purchasedShares = 0;
        mintRequest.tokenId = 0;
        mintRequest.isMinted = false;
        mintRequest.exists = true;
        currentRequestId = requestId;
    }

    function addShare(uint256 amount) external payable whenNotPaused {
        require(mintRequests[currentRequestId].exists, "!Mint request");

        MintRequest storage mintRequest = mintRequests[currentRequestId];

        require(!mintRequest.isMinted, "It's already minted!");
        require(
            amount > 0 && amount <= (sharesCount - mintRequest.purchasedShares),
            "Invalid share amount!"
        );

        uint256 shareValue = amount * sharePrice;

        if (paymentToken == address(0)) {
            require(msg.value == shareValue, "!msg.value");
        } else {
            IERC20 token = IERC20(paymentToken);
            token.transferFrom(msg.sender, address(this), shareValue);
        }

        mintRequest.shares.push(
            MintShare({
                stakeholder: msg.sender,
                amount: amount,
                price: sharePrice
            })
        );
        mintRequest.purchasedShares += amount;

        if (mintRequest.purchasedShares == sharesCount) {
            mintNFT();
        }
    }

    function deleteShare(
        uint256 requestId,
        uint256 index
    ) external whenNotPaused {
        require(mintRequests[requestId].exists, "!Mint request");

        MintRequest storage mintRequest = mintRequests[requestId];

        require(
            index >= 0 && index < mintRequest.shares.length,
            "Invalid index!"
        );

        MintShare memory share = mintRequest.shares[index];
        require(
            !mintRequest.isMinted && (msg.sender == share.stakeholder),
            "Permission denied!"
        );

        mintRequest.purchasedShares -= share.amount;

        // Delete the share from the shares list
        for (uint256 i = index; i < mintRequest.shares.length - 1; i++) {
            mintRequest.shares[i] = mintRequest.shares[i + 1];
        }
        mintRequest.shares.pop();

        uint256 shareValue = share.amount * share.price;

        if (paymentToken == address(0)) {
            payable(msg.sender).transfer(shareValue);
        } else {
            IERC20(paymentToken).transfer(msg.sender, shareValue);
        }
    }

    function mintNFT() private {
        MintRequest storage mintRequest = mintRequests[currentRequestId];

        IDivvyERC721 nftToken = IDivvyERC721(addr);

        uint256 tokenId = nftToken.divvyMint(address(this));

        mintRequest.tokenId = tokenId;
        mintRequest.isMinted = true;

        for (uint256 i = 0; i < mintRequest.shares.length; i++) {
            MintShare memory share = mintRequest.shares[i];
            balance += (share.amount * share.price);
        }

        uint256 requestId = currentRequestId;

        newMintRequest();

        emit Mint(requestId, tokenId);
    }

    function getStakeholders(
        uint256 requestId
    ) public view returns (address[] memory stakeholders) {
        MintRequest memory mintRequest = mintRequests[requestId];

        stakeholders = new address[](mintRequest.shares.length);
        for (uint256 i = 0; i < mintRequest.shares.length; i++) {
            stakeholders[i] = mintRequest.shares[i].stakeholder;
        }
    }

    function getShare(
        uint256 requestId,
        uint256 index
    ) public view returns (address stakeholder, uint256 amount, uint256 price) {
        MintRequest memory mintRequest = mintRequests[requestId];

        stakeholder = mintRequest.shares[index].stakeholder;
        amount = mintRequest.shares[index].amount;
        price = mintRequest.shares[index].price;
    }

    function withdrawFunds(
        address to,
        uint256 amount
    ) external onlyOwner whenNotPaused {
        require(amount > 0, "!amount");
        require(balance > 0 && amount <= balance, "!balance");

        balance -= amount;

        if (paymentToken == address(0)) {
            payable(to).transfer(amount);
        } else {
            IERC20(paymentToken).transfer(to, amount);
        }
    }

    function transferToken(
        uint256 requestId,
        address to
    ) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        require(mintRequests[requestId].exists, "!Mint request");

        MintRequest storage mintRequest = mintRequests[requestId];

        require(mintRequest.tokenId != 0, "!tokenId");

        mintRequest.tokenId = 0;

        IDivvyERC721 nftToken = IDivvyERC721(addr);
        nftToken.safeTransferFrom(address(this), to, mintRequest.tokenId);
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
