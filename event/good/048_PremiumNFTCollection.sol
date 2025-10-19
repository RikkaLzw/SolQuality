
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PremiumNFTCollection is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public mintPrice = 0.05 ether;
    uint256 public maxMintsPerAddress = 10;
    bool public mintingEnabled = false;
    string private _baseTokenURI;

    mapping(address => uint256) public mintedByAddress;
    mapping(uint256 => bool) public tokenExists;


    event TokenMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event MintPriceUpdated(uint256 indexed oldPrice, uint256 indexed newPrice);
    event MintingStatusChanged(bool indexed enabled);
    event MaxMintsPerAddressUpdated(uint256 indexed oldLimit, uint256 indexed newLimit);
    event BaseURIUpdated(string indexed newBaseURI);
    event TokenURIUpdated(uint256 indexed tokenId, string newTokenURI);
    event WithdrawalCompleted(address indexed recipient, uint256 indexed amount);

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) ERC721(name, symbol) {
        require(bytes(name).length > 0, "PremiumNFT: Name cannot be empty");
        require(bytes(symbol).length > 0, "PremiumNFT: Symbol cannot be empty");
        _baseTokenURI = baseTokenURI;
        emit BaseURIUpdated(baseTokenURI);
    }

    modifier onlyWhenMintingEnabled() {
        require(mintingEnabled, "PremiumNFT: Minting is currently disabled");
        _;
    }

    modifier validTokenId(uint256 tokenId) {
        require(tokenExists[tokenId], "PremiumNFT: Token does not exist");
        _;
    }

    function mint(address to, string memory tokenURI)
        external
        payable
        onlyWhenMintingEnabled
        nonReentrant
    {
        require(to != address(0), "PremiumNFT: Cannot mint to zero address");
        require(msg.value >= mintPrice, "PremiumNFT: Insufficient payment for minting");
        require(bytes(tokenURI).length > 0, "PremiumNFT: Token URI cannot be empty");

        uint256 currentSupply = _tokenIdCounter.current();
        require(currentSupply < MAX_SUPPLY, "PremiumNFT: Maximum supply reached");

        uint256 addressMintCount = mintedByAddress[to];
        require(addressMintCount < maxMintsPerAddress, "PremiumNFT: Exceeds maximum mints per address");

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        mintedByAddress[to]++;
        tokenExists[tokenId] = true;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);

        emit TokenMinted(to, tokenId, tokenURI);


        if (msg.value > mintPrice) {
            uint256 refund = msg.value - mintPrice;
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            require(success, "PremiumNFT: Refund transfer failed");
        }
    }

    function batchMint(
        address[] calldata recipients,
        string[] calldata tokenURIs
    ) external onlyOwner {
        require(recipients.length > 0, "PremiumNFT: Recipients array cannot be empty");
        require(recipients.length == tokenURIs.length, "PremiumNFT: Arrays length mismatch");
        require(recipients.length <= 50, "PremiumNFT: Batch size too large");

        uint256 currentSupply = _tokenIdCounter.current();
        require(currentSupply + recipients.length <= MAX_SUPPLY, "PremiumNFT: Batch exceeds maximum supply");

        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            string memory tokenURI = tokenURIs[i];

            require(recipient != address(0), "PremiumNFT: Cannot mint to zero address");
            require(bytes(tokenURI).length > 0, "PremiumNFT: Token URI cannot be empty");

            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();

            tokenExists[tokenId] = true;

            _safeMint(recipient, tokenId);
            _setTokenURI(tokenId, tokenURI);

            emit TokenMinted(recipient, tokenId, tokenURI);
        }
    }

    function burn(uint256 tokenId) external validTokenId(tokenId) {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "PremiumNFT: Caller is not owner nor approved");

        tokenExists[tokenId] = false;
        _burn(tokenId);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;
        emit MintPriceUpdated(oldPrice, newPrice);
    }

    function setMaxMintsPerAddress(uint256 newLimit) external onlyOwner {
        require(newLimit > 0, "PremiumNFT: Limit must be greater than zero");
        uint256 oldLimit = maxMintsPerAddress;
        maxMintsPerAddress = newLimit;
        emit MaxMintsPerAddressUpdated(oldLimit, newLimit);
    }

    function setMintingEnabled(bool enabled) external onlyOwner {
        mintingEnabled = enabled;
        emit MintingStatusChanged(enabled);
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function setTokenURI(uint256 tokenId, string calldata newTokenURI)
        external
        onlyOwner
        validTokenId(tokenId)
    {
        require(bytes(newTokenURI).length > 0, "PremiumNFT: Token URI cannot be empty");
        _setTokenURI(tokenId, newTokenURI);
        emit TokenURIUpdated(tokenId, newTokenURI);
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "PremiumNFT: No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "PremiumNFT: Withdrawal failed");

        emit WithdrawalCompleted(owner(), balance);
    }

    function emergencyWithdraw(address payable recipient) external onlyOwner nonReentrant {
        require(recipient != address(0), "PremiumNFT: Invalid recipient address");

        uint256 balance = address(this).balance;
        require(balance > 0, "PremiumNFT: No funds to withdraw");

        (bool success, ) = recipient.call{value: balance}("");
        require(success, "PremiumNFT: Emergency withdrawal failed");

        emit WithdrawalCompleted(recipient, balance);
    }


    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - _tokenIdCounter.current();
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        validTokenId(tokenId)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


    receive() external payable {
        revert("PremiumNFT: Direct ETH transfers not allowed");
    }

    fallback() external payable {
        revert("PremiumNFT: Function does not exist");
    }
}
