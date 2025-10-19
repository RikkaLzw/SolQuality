
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract InefficientNFTCollection is ERC721, Ownable {
    using Counters for Counters.Counter;


    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;
    uint256 public maxMintPerAddress = 5;
    uint256 public isPublicSaleActive = 1;
    uint256 public isWhitelistSaleActive = 0;

    Counters.Counter private _tokenIds;


    mapping(uint256 => string) public tokenCategories;
    mapping(address => uint256) public mintedCount;
    mapping(address => uint256) public isWhitelisted;


    mapping(uint256 => bytes) public tokenMetadata;

    string private _baseTokenURI;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI
    ) ERC721(name, symbol) {
        _baseTokenURI = baseURI;
    }

    function setPublicSaleActive(uint256 _isActive) external onlyOwner {

        isPublicSaleActive = _isActive;
    }

    function setWhitelistSaleActive(uint256 _isActive) external onlyOwner {

        isWhitelistSaleActive = _isActive;
    }

    function addToWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {

            isWhitelisted[addresses[uint256(i)]] = uint256(1);
        }
    }

    function removeFromWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {

            isWhitelisted[addresses[uint256(i)]] = uint256(0);
        }
    }

    function whitelistMint(uint256 quantity, string memory category) external payable {
        require(isWhitelistSaleActive == 1, "Whitelist sale not active");
        require(isWhitelisted[msg.sender] == 1, "Not whitelisted");
        require(quantity > 0, "Quantity must be greater than 0");


        uint256 currentSupply = uint256(_tokenIds.current());
        require(currentSupply + quantity <= maxSupply, "Exceeds max supply");
        require(mintedCount[msg.sender] + quantity <= maxMintPerAddress, "Exceeds max mint per address");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        mintedCount[msg.sender] += quantity;

        for (uint256 i = 0; i < quantity; i++) {
            _tokenIds.increment();
            uint256 tokenId = _tokenIds.current();
            _safeMint(msg.sender, tokenId);


            tokenCategories[tokenId] = category;


            tokenMetadata[tokenId] = abi.encodePacked("metadata_", tokenId);
        }
    }

    function publicMint(uint256 quantity, string memory category) external payable {
        require(isPublicSaleActive == 1, "Public sale not active");
        require(quantity > 0, "Quantity must be greater than 0");


        uint256 currentSupply = uint256(_tokenIds.current());
        require(currentSupply + quantity <= maxSupply, "Exceeds max supply");
        require(mintedCount[msg.sender] + quantity <= maxMintPerAddress, "Exceeds max mint per address");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        mintedCount[msg.sender] += quantity;

        for (uint256 i = 0; i < quantity; i++) {
            _tokenIds.increment();
            uint256 tokenId = _tokenIds.current();
            _safeMint(msg.sender, tokenId);


            tokenCategories[tokenId] = category;


            tokenMetadata[tokenId] = abi.encodePacked("metadata_", tokenId);
        }
    }

    function ownerMint(address to, uint256 quantity, string memory category) external onlyOwner {

        uint256 currentSupply = uint256(_tokenIds.current());
        require(currentSupply + quantity <= maxSupply, "Exceeds max supply");

        for (uint256 i = 0; i < quantity; i++) {
            _tokenIds.increment();
            uint256 tokenId = _tokenIds.current();
            _safeMint(to, tokenId);


            tokenCategories[tokenId] = category;


            tokenMetadata[tokenId] = abi.encodePacked("owner_mint_", tokenId);
        }
    }

    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
    }

    function setMaxSupply(uint256 _maxSupply) external onlyOwner {
        require(_maxSupply >= _tokenIds.current(), "Cannot set max supply below current supply");
        maxSupply = _maxSupply;
    }

    function setMaxMintPerAddress(uint256 _maxMint) external onlyOwner {
        maxMintPerAddress = _maxMint;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function totalSupply() public view returns (uint256) {

        return uint256(_tokenIds.current());
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");

        return bytes(_baseTokenURI).length > 0
            ? string(abi.encodePacked(_baseTokenURI, Strings.toString(tokenId)))
            : "";
    }

    function getTokenCategory(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        return tokenCategories[tokenId];
    }

    function getTokenMetadata(uint256 tokenId) public view returns (bytes memory) {
        require(_exists(tokenId), "Token does not exist");
        return tokenMetadata[tokenId];
    }

    function isAddressWhitelisted(address addr) public view returns (uint256) {

        return isWhitelisted[addr];
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}
