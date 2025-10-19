
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract InefficientNFTCollection is ERC721, Ownable {
    using Counters for Counters.Counter;


    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;
    uint256 public maxPerWallet = 5;
    uint256 public isPublicSaleActive = 1;
    uint256 public isWhitelistSaleActive = 0;

    Counters.Counter private _tokenIdCounter;


    mapping(uint256 => string) public tokenCategories;
    mapping(address => uint256) public mintedCount;
    mapping(address => uint256) public isWhitelisted;


    mapping(uint256 => bytes) public tokenMetadata;

    string private baseTokenURI;

    constructor(
        string memory name,
        string memory symbol,
        string memory _baseTokenURI
    ) ERC721(name, symbol) {
        baseTokenURI = _baseTokenURI;
        _tokenIdCounter.increment();
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


        require(
            mintedCount[msg.sender] + quantity <= uint256(maxPerWallet),
            "Exceeds max per wallet"
        );

        uint256 currentSupply = _tokenIdCounter.current() - 1;
        require(
            currentSupply + quantity <= maxSupply,
            "Exceeds max supply"
        );


        require(
            msg.value >= mintPrice * uint256(quantity),
            "Insufficient payment"
        );

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(msg.sender, tokenId);


            tokenCategories[tokenId] = category;


            tokenMetadata[tokenId] = abi.encodePacked(
                "metadata_",
                Strings.toString(tokenId)
            );

            _tokenIdCounter.increment();
        }


        mintedCount[msg.sender] += uint256(quantity);
    }

    function publicMint(uint256 quantity, string memory category) external payable {
        require(isPublicSaleActive == 1, "Public sale not active");
        require(quantity > 0, "Quantity must be greater than 0");


        require(
            mintedCount[msg.sender] + quantity <= uint256(maxPerWallet),
            "Exceeds max per wallet"
        );

        uint256 currentSupply = _tokenIdCounter.current() - 1;
        require(
            currentSupply + quantity <= maxSupply,
            "Exceeds max supply"
        );


        require(
            msg.value >= mintPrice * uint256(quantity),
            "Insufficient payment"
        );

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(msg.sender, tokenId);


            tokenCategories[tokenId] = category;


            tokenMetadata[tokenId] = abi.encodePacked(
                "metadata_",
                Strings.toString(tokenId)
            );

            _tokenIdCounter.increment();
        }


        mintedCount[msg.sender] += uint256(quantity);
    }

    function ownerMint(address to, uint256 quantity, string memory category) external onlyOwner {
        require(quantity > 0, "Quantity must be greater than 0");

        uint256 currentSupply = _tokenIdCounter.current() - 1;
        require(
            currentSupply + quantity <= maxSupply,
            "Exceeds max supply"
        );

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(to, tokenId);


            tokenCategories[tokenId] = category;


            tokenMetadata[tokenId] = abi.encodePacked(
                "owner_mint_",
                Strings.toString(tokenId)
            );

            _tokenIdCounter.increment();
        }
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    function setMaxPerWallet(uint256 _maxPerWallet) external onlyOwner {
        maxPerWallet = _maxPerWallet;
    }

    function setBaseURI(string memory _baseTokenURI) external onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current() - 1;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");

        return bytes(baseTokenURI).length > 0
            ? string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId)))
            : "";
    }

    function getTokenMetadata(uint256 tokenId) external view returns (bytes memory) {
        require(_exists(tokenId), "Token does not exist");
        return tokenMetadata[tokenId];
    }

    function getTokenCategory(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        return tokenCategories[tokenId];
    }


    function checkWhitelistStatus(address account) external view returns (uint256) {
        return isWhitelisted[account];
    }
}
