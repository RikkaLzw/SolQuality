
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract PremiumNFTCollection is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard, Pausable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;


    uint256 public constant MAX_SUPPLY = 10000;


    uint256 public mintPrice = 0.01 ether;


    uint256 public constant MAX_TOKENS_PER_TX = 10;


    string private _baseTokenURI;


    mapping(address => uint256) public mintedTokens;


    uint256 public maxTokensPerAddress = 50;


    event TokenMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event MintPriceUpdated(uint256 indexed oldPrice, uint256 indexed newPrice);
    event MaxTokensPerAddressUpdated(uint256 indexed oldLimit, uint256 indexed newLimit);
    event BaseURIUpdated(string indexed oldBaseURI, string indexed newBaseURI);
    event TokenURIUpdated(uint256 indexed tokenId, string indexed newTokenURI);
    event WithdrawalCompleted(address indexed recipient, uint256 indexed amount);
    event BatchMintCompleted(address indexed to, uint256 indexed startTokenId, uint256 indexed quantity);

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) ERC721(name, symbol) {
        require(bytes(name).length > 0, "PremiumNFTCollection: Name cannot be empty");
        require(bytes(symbol).length > 0, "PremiumNFTCollection: Symbol cannot be empty");
        require(bytes(baseTokenURI).length > 0, "PremiumNFTCollection: Base URI cannot be empty");

        _baseTokenURI = baseTokenURI;
        emit BaseURIUpdated("", baseTokenURI);
    }


    function mint() external payable nonReentrant whenNotPaused {
        require(msg.value >= mintPrice, "PremiumNFTCollection: Insufficient payment for minting");
        require(_tokenIdCounter.current() < MAX_SUPPLY, "PremiumNFTCollection: Maximum supply reached");
        require(mintedTokens[msg.sender] < maxTokensPerAddress, "PremiumNFTCollection: Exceeds maximum tokens per address");

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        mintedTokens[msg.sender]++;

        _safeMint(msg.sender, tokenId);

        string memory tokenURI = string(abi.encodePacked(_baseTokenURI, Strings.toString(tokenId)));
        _setTokenURI(tokenId, tokenURI);

        emit TokenMinted(msg.sender, tokenId, tokenURI);


        if (msg.value > mintPrice) {
            payable(msg.sender).transfer(msg.value - mintPrice);
        }
    }


    function mintBatch(uint256 quantity) external payable nonReentrant whenNotPaused {
        require(quantity > 0, "PremiumNFTCollection: Quantity must be greater than zero");
        require(quantity <= MAX_TOKENS_PER_TX, "PremiumNFTCollection: Exceeds maximum tokens per transaction");
        require(msg.value >= mintPrice * quantity, "PremiumNFTCollection: Insufficient payment for batch minting");
        require(_tokenIdCounter.current() + quantity <= MAX_SUPPLY, "PremiumNFTCollection: Would exceed maximum supply");
        require(mintedTokens[msg.sender] + quantity <= maxTokensPerAddress, "PremiumNFTCollection: Would exceed maximum tokens per address");

        uint256 startTokenId = _tokenIdCounter.current();

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();

            _safeMint(msg.sender, tokenId);

            string memory tokenURI = string(abi.encodePacked(_baseTokenURI, Strings.toString(tokenId)));
            _setTokenURI(tokenId, tokenURI);

            emit TokenMinted(msg.sender, tokenId, tokenURI);
        }

        mintedTokens[msg.sender] += quantity;
        emit BatchMintCompleted(msg.sender, startTokenId, quantity);


        uint256 totalCost = mintPrice * quantity;
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
    }


    function ownerMint(address to, uint256 quantity) external onlyOwner {
        require(to != address(0), "PremiumNFTCollection: Cannot mint to zero address");
        require(quantity > 0, "PremiumNFTCollection: Quantity must be greater than zero");
        require(_tokenIdCounter.current() + quantity <= MAX_SUPPLY, "PremiumNFTCollection: Would exceed maximum supply");

        uint256 startTokenId = _tokenIdCounter.current();

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();

            _safeMint(to, tokenId);

            string memory tokenURI = string(abi.encodePacked(_baseTokenURI, Strings.toString(tokenId)));
            _setTokenURI(tokenId, tokenURI);

            emit TokenMinted(to, tokenId, tokenURI);
        }

        emit BatchMintCompleted(to, startTokenId, quantity);
    }


    function setMintPrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "PremiumNFTCollection: Price must be greater than zero");
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;
        emit MintPriceUpdated(oldPrice, newPrice);
    }


    function setMaxTokensPerAddress(uint256 newLimit) external onlyOwner {
        require(newLimit > 0, "PremiumNFTCollection: Limit must be greater than zero");
        uint256 oldLimit = maxTokensPerAddress;
        maxTokensPerAddress = newLimit;
        emit MaxTokensPerAddressUpdated(oldLimit, newLimit);
    }


    function setBaseURI(string memory newBaseURI) external onlyOwner {
        require(bytes(newBaseURI).length > 0, "PremiumNFTCollection: Base URI cannot be empty");
        string memory oldBaseURI = _baseTokenURI;
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(oldBaseURI, newBaseURI);
    }


    function setTokenURI(uint256 tokenId, string memory newTokenURI) external onlyOwner {
        require(_exists(tokenId), "PremiumNFTCollection: Token does not exist");
        require(bytes(newTokenURI).length > 0, "PremiumNFTCollection: Token URI cannot be empty");

        _setTokenURI(tokenId, newTokenURI);
        emit TokenURIUpdated(tokenId, newTokenURI);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "PremiumNFTCollection: No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "PremiumNFTCollection: Withdrawal failed");

        emit WithdrawalCompleted(owner(), balance);
    }


    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current();
    }


    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - _tokenIdCounter.current();
    }


    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }


    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }


    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }


    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }


    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }


    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
}
