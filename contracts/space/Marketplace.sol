// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/IERC20.sol";
import "../interfaces/IMarketplace.sol";
import "../dependencies/OwnableUpgradeable.sol";
import "../dependencies/ReentrancyGuardUpgradeable.sol";
import "../ERC721Marketplace/ERC721Marketplace.sol";

contract Marketplace is Initializable, IMarketplace, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    uint256 internal _auctionStep;
    uint256 internal _gracePeriod;

    //keeping track of genuine collections
    mapping(address => bool) internal _collections;
    //keeping track of imported collections
    mapping(address => bool) internal _externalCollections;
    address[] internal _allCollections;
    address[] internal _allExternalCollections;
    //bids that were not able to be transferred back are going here, we protect our listings
    mapping(address => uint256) public unreturnedBids;

    mapping(address => mapping(uint256 => ListingInfo)) internal listingInfos;

    // MAX royalty is 50%
    uint256 public constant MAX_ROYALTY = 10**18 / 2;

    function initialize(
        uint256 auctionStep,
        uint256 gracePeriod
    ) public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        _auctionStep = auctionStep;
        _gracePeriod = gracePeriod;
    }

    function createNFTWithAuction(
        address collection,
        string calldata tokenURI,
        uint256 timeStart,
        uint256 duration,
        uint256 minimalBid,
        uint256 royalty
    ) external override {
        require(minimalBid > 0, "Marketplace: Cannot list with zero minimal bid");
        require(royalty <= MAX_ROYALTY, "Marketplace: Resale royalty is too high");
        uint256 tokenId = ERC721Marketplace(collection).mint(tokenURI, msg.sender, address(this), royalty);
        _startListing(collection, tokenId, timeStart, duration, minimalBid, ListingType.Auction);
    }

    function createNFTWithFixedPrice(
        address collection,
        string calldata tokenURI,
        uint256 timeStart,
        uint256 duration,
        uint256 value,
        uint256 royalty
    ) external override {
        require(value > 0, "Marketplace: Cannot list with zero value");
        require(royalty <= MAX_ROYALTY, "Marketplace: Resell royalty is too high");
        uint256 tokenId = ERC721Marketplace(collection).mint(tokenURI, msg.sender, address(this), royalty);
        _startListing(collection, tokenId, timeStart, duration, value, ListingType.FixedPrice);
    }

    function startAuction(
        address collection,
        uint256 tokenId,
        uint256 timeStart,
        uint256 duration,
        uint256 minimalBid
    ) external override {
        require(minimalBid > 0, "Marketplace: Cannot list with zero minimal bid");
        ListingStatus status = _getListingStatus(collection, tokenId);
        ListingInfo storage listing = listingInfos[collection][tokenId];
        bool isOwnedBySender = msg.sender == ERC721Marketplace(collection).ownerOf(tokenId);

        require(
            (_collections[collection] || _externalCollections[collection]) &&
            (
                isOwnedBySender ||
                (
                    status == ListingStatus.Rejected &&
                    msg.sender == listing.creator
                )
            ),
            "Marketplace: Cannot start listing"
        );

        if (isOwnedBySender) {
            ERC721Marketplace(collection).transferFrom(msg.sender, address(this), tokenId);
        }
        require(ERC721Marketplace(collection).ownerOf(tokenId) == address(this), "Marketplace: Space should own item to start listing");
        _startListing(collection, tokenId, timeStart, duration, minimalBid, ListingType.Auction);
    }

    function startFixedPrice(
        address collection,
        uint256 tokenId,
        uint256 timeStart,
        uint256 duration,
        uint256 value
    ) external override {
        require(value > 0, "Marketplace: Cannot list with zero value");
        ListingStatus status = _getListingStatus(collection, tokenId);
        ListingInfo storage listing = listingInfos[collection][tokenId];
        bool isOwnedBySender = msg.sender == ERC721Marketplace(collection).ownerOf(tokenId);

        require(
            (_collections[collection] || _externalCollections[collection]) &&
            (
                isOwnedBySender ||
                (
                    status == ListingStatus.Rejected &&
                    msg.sender == listing.creator
                )
            ),
            "Marketplace: Cannot start listing"
        );
        if (isOwnedBySender) {
            ERC721Marketplace(collection).transferFrom(msg.sender, address(this), tokenId);
        }
        require(ERC721Marketplace(collection).ownerOf(tokenId) == address(this), "Marketplace: Space should own item to start listing");
        _startListing(collection, tokenId, timeStart, duration, value, ListingType.FixedPrice);
    }

    function _startListing(
        address collection,
        uint256 tokenId,
        uint256 timeStart,
        uint256 duration,
        uint256 minimalBid,
        ListingType listingType
    ) internal {
        ListingInfo storage listing = listingInfos[collection][tokenId];
        listing.blockOfCreation = block.number;
        listing.timeStart = timeStart;
        listing.duration = duration;
        listing.minimalBid = minimalBid;
        listing.lastBid = 0;
        listing.lastBidder = address(0);
        listing.listingType = listingType;
        listing.creator = msg.sender;
        emit ListingStarted(collection, tokenId, listingType, minimalBid, block.number);
    }

    function getListingType(address collection, uint256 tokenId) external view override returns (ListingType) {
        return listingInfos[collection][tokenId].listingType;
    }

    function getListingStatus(address collection, uint256 tokenId) external view override returns (ListingStatus) {
        return _getListingStatus(collection, tokenId);
    }

    function _getListingStatus(address collection, uint256 tokenId) internal view returns (ListingStatus) {
        ListingInfo storage listingInfo = listingInfos[collection][tokenId];
        if (listingInfo.timeStart > block.timestamp) {
            return ListingStatus.Pending;
        }
        if (listingInfo.timeStart + listingInfo.duration > block.timestamp) {
            if (listingInfo.listingType == ListingType.FixedPrice && listingInfo.lastBid != 0) {
                return ListingStatus.Successful;
            }
            return ListingStatus.Active;
        }
        if (listingInfo.lastBid != 0) {
            return ListingStatus.Successful;
        }
        return ListingStatus.Rejected;
    }

    function getListingInfo(address collection, uint256 tokenId) external view override returns (ListingInfo memory) {
        return listingInfos[collection][tokenId];
    }

    function allCollectionsLength() external view override returns (uint256) {
        return _allCollections.length;
    }

    function allExternalCollectionsLength() external view override returns (uint256) {
        return _allExternalCollections.length;
    }

    function getCollection(uint256 index) external view override returns (address) {
        return _allCollections[index];
    }

    function getExternalCollection(uint256 index) external view override returns (address) {
        return _allExternalCollections[index];
    }

    function auctionStep() external view override returns (uint256) {
        return _auctionStep;
    }

    function gracePeriod() external view override returns (uint256) {
        return _gracePeriod;
    }

    function setAuctionStep(uint256 newAuctionStep) external override onlyOwner {
        _auctionStep = newAuctionStep;
        emit AuctionStepChanged(newAuctionStep);
    }

    function setGracePeriod(uint256 newGracePeriod) external override onlyOwner {
        _gracePeriod = newGracePeriod;
        emit GracePeriodChanged(newGracePeriod);
    }

    function createCollection(
        string calldata collectionURI,
        string calldata name,
        string calldata symbol
    ) external override returns (address collection) {
        ERC721Marketplace collection = new ERC721Marketplace(address(this), collectionURI, name, symbol, msg.sender);
        _allCollections.push(address(collection));
        _collections[address(collection)] = true;
        emit CollectionCreated(address(collection), msg.sender, name, symbol);
        return address(collection);
    }

    function importCollection(
        address collection
    ) external override onlyOwner {
        require(!_externalCollections[collection], "Marketplace: Collection already imported");
        _allExternalCollections.push(collection);
        _externalCollections[collection] = true;
        emit CollectionImported(collection);
    }

    function importNativeCollection(
        address collection
    ) external onlyOwner {
        require(!_collections[collection], "Marketplace: Collection already imported");
        _allCollections.push(collection);
        _collections[collection] = true;
    }

    function bid(address collection, uint256 tokenId) external override payable nonReentrant {
        require(_getListingStatus(collection, tokenId) == ListingStatus.Active);
        ListingInfo storage listing = listingInfos[collection][tokenId];
        require(listing.listingType == ListingType.Auction, "Marketplace: Bid on non-auction listing");
        uint256 minimumToBid = listing.minimalBid;
        uint256 lastBid = listing.lastBid;
        if (lastBid != 0) {
            minimumToBid = lastBid;
        }
        require(msg.value >= minimumToBid + _auctionStep, "Marketplace: Bid too low");
        uint256 timeTillEnd = listing.timeStart + listing.duration - block.timestamp;
        if (timeTillEnd < _gracePeriod) {
            listing.duration += _gracePeriod - timeTillEnd;
        }
        if (lastBid != 0) {
            (bool sent, ) = payable(listing.lastBidder).call{value: lastBid}("");
            if(!sent) {
                unreturnedBids[listing.lastBidder] += lastBid;
            }
        }

        uint256 bidDelta = msg.value - lastBid;
        if (_externalCollections[collection]) {
            payable(listing.creator).call{value: bidDelta}("");
        }
        else if(_collections[collection]) {
            address tokenIdCreator = ERC721Marketplace(collection).creator(tokenId);

            if (listing.creator == tokenIdCreator) {
                payable(tokenIdCreator).call{value: bidDelta}("");
            }
            else {
                uint256 royalty = ERC721Marketplace(collection).getRoyalty(tokenId);
                uint256 royaltyAmount = bidDelta * royalty / 10**18;
                uint256 sellerAmount = bidDelta - royaltyAmount;
                payable(listing.creator).call{value: sellerAmount}("");
                payable(tokenIdCreator).call{value: royaltyAmount}("");
            }
        }

        listing.lastBidder = msg.sender;
        listing.lastBid = msg.value;
        emit AuctionBid(collection, tokenId, msg.sender, msg.value, block.timestamp);
    }

    function purchase(address collection, uint256 tokenId) external override payable nonReentrant {
        require(_getListingStatus(collection, tokenId) == ListingStatus.Active);
        ListingInfo storage listing = listingInfos[collection][tokenId];
        require(listing.listingType == ListingType.FixedPrice, "Marketplace: Cannot purchase non-fixed-price");
        uint256 price = listing.minimalBid;
        require(msg.value == price, "Marketplace: msg.value doesn't match value");
        listing.lastBidder = msg.sender;
        listing.lastBid = msg.value;
        IERC721(collection).transferFrom(address(this), msg.sender, tokenId);

        if (_externalCollections[collection]) {
            payable(listing.creator).call{value: price}("");
        }
        else if(_collections[collection]) {
            address tokenIdCreator = ERC721Marketplace(collection).creator(tokenId);
            if (listing.creator == tokenIdCreator) {
                payable(tokenIdCreator).call{value: price}("");
            }
            else {
                uint256 royalty = ERC721Marketplace(collection).getRoyalty(tokenId);
                uint256 royaltyAmount = price * royalty / 10**18;
                uint256 sellerAmount = price - royaltyAmount;
                payable(listing.creator).call{value: sellerAmount}("");
                payable(tokenIdCreator).call{value: royaltyAmount}("");
            }
        }

        emit NFTPurchased(collection, tokenId, msg.sender, msg.value);
    }

    function claimNFT(address collection, uint256 tokenId) external override nonReentrant {
        require(_getListingStatus(collection, tokenId) == ListingStatus.Successful, "Marketplace: Listing is not over yet");
        ListingInfo memory listing = listingInfos[collection][tokenId];
        require(listing.lastBidder == msg.sender, "Marketplace: Only winner can claim");
        IERC721(collection).transferFrom(address(this), listing.lastBidder, tokenId);

        emit NFTClaimed(collection, tokenId, listing.lastBidder, listing.lastBid);
    }

    function returnFromSale(address collection, uint256 tokenId) external override {
        require(_getListingStatus(collection, tokenId) == ListingStatus.Rejected, "Marketplace: Listing is not over yet");
        ListingInfo memory listing = listingInfos[collection][tokenId];
        require(listing.creator == msg.sender, "Marketplace: Only creator can perform");

        IERC721(collection).transferFrom(address(this), msg.sender, tokenId);
        emit NFTReturnedFromSale(collection, tokenId, msg.sender);
    }

    function stopListing(address collection, uint256 tokenId) external override {
        ListingStatus status = _getListingStatus(collection, tokenId);
        ListingInfo memory listing = listingInfos[collection][tokenId];
        require(listing.creator == msg.sender, "Marketplace: Only creator can perform");
        require(
            status == ListingStatus.Pending || (
                status == ListingStatus.Active &&
                (
                    (listing.listingType == ListingType.Auction && listing.lastBid == 0) ||
                    listing.listingType == ListingType.FixedPrice
                )
            ), "Marketplace: Cannot stop this listing"
        );
        listingInfos[collection][tokenId].timeStart = 0;
        listingInfos[collection][tokenId].duration = 0;
        emit ListingStarted(collection, tokenId, listing.listingType, listing.minimalBid, block.number);
    }

    function claimUnreturnedBids() external override nonReentrant {
        uint256 amount = unreturnedBids[msg.sender];
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        if (sent) {
            unreturnedBids[msg.sender] = 0;
        }
        emit UnreturnedBidsClaimed(msg.sender, amount);
    }
}
