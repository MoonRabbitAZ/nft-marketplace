// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import "../dependencies/Ownable.sol";
import "../dependencies/ERC721Enumerable.sol";
import "../interfaces/IMarketplace.sol";

contract ERC721Marketplace is ERC721Enumerable, Ownable {
    string internal _collectionURI;
    IMarketplace internal _marketplace;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => uint256) internal _royalties;
    mapping(uint256 => address) internal _creators;
    bool internal _isDetached;
    string public baseURI;

    constructor(
        address marketplace_,
        string memory collectionURI_,
        string memory name_,
        string memory symbol_,
        address newOwner_
    ) ERC721(name_, symbol_) {
        _marketplace = IMarketplace(marketplace_);
        _collectionURI = collectionURI_;
        baseURI = "ipfs://";
        transferOwnership(newOwner_);
    }

    function mint(
        string calldata tokenURI,
        address creator,
        address receiver,
        uint256 royalty
    ) external returns (uint256) {
        require(
            msg.sender == owner() ||
            (
                !_isDetached &&
                msg.sender == address(_marketplace) &&
                creator == owner()
            ),
                "ERC721Marketplace: No permissions to mint"
        );
        uint256 supply = totalSupply();
        _mint(receiver, supply);
        _setTokenURI(supply, tokenURI);
        _creators[supply] = creator;
        _royalties[supply] = royalty;
        return supply;
    }

    function mintSpecific(
        uint256 tokenId,
        string calldata tokenURI,
        address creator,
        address receiver,
        uint256 royalty
    ) external returns (uint256) {
        require(
            msg.sender == owner() ||
            (
                !_isDetached &&
                msg.sender == address(_marketplace) &&
                creator == owner()
            ),
                "ERC721Marketplace: No permissions to mint"
        );
        _mint(receiver, tokenId);
        _setTokenURI(tokenId, tokenURI);
        _creators[tokenId] = creator;
        _royalties[tokenId] = royalty;
        return tokenId;
    }

    function creator(uint256 tokenId) external view returns (address) {
        return _creators[tokenId];
    }

    function marketplace() external view returns (address) {
        return address(_marketplace);
    }

    function collectionURI() external view returns (string memory) {
        return _collectionURI;
    }

    function getRoyalty(uint256 tokenId) external view returns (uint256) {
        return _royalties[tokenId];
    }

    function toggleDetached() external onlyOwner {
        _isDetached = !_isDetached;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
}
