
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract PremiumNFTCollection is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Pausable,
    Ownable,
    ReentrancyGuard
{
    using Strings for uint256;


    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_MINT_PER_TX = 20;
    uint256 public constant MAX_MINT_PER_WALLET = 100;
    uint256 public constant MINT_PRICE = 0.08 ether;


    uint256 private _currentTokenId;
    string private _baseTokenURI;
    bool public mintingEnabled;


    mapping(address => uint256) private _mintedPerWallet;


    event MintingStatusChanged(bool enabled);
    event BaseURIUpdated(string newBaseURI);
    event TokenMinted(address indexed to, uint256 indexed tokenId);
    event FundsWithdrawn(address indexed to, uint256 amount);


    modifier onlyWhenMintingEnabled() {
        require(mintingEnabled, "Minting is currently disabled");
        _;
    }

    modifier validMintAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= MAX_MINT_PER_TX, "Exceeds max mint per transaction");
        _;
    }

    modifier supplyAvailable(uint256 amount) {
        require(_currentTokenId + amount <= MAX_SUPPLY, "Exceeds maximum supply");
        _;
    }

    modifier walletMintLimit(address wallet, uint256 amount) {
        require(
            _mintedPerWallet[wallet] + amount <= MAX_MINT_PER_WALLET,
            "Exceeds max mint per wallet"
        );
        _;
    }

    modifier sufficientPayment(uint256 amount) {
        require(msg.value >= MINT_PRICE * amount, "Insufficient payment");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI,
        address initialOwner
    ) ERC721(name, symbol) Ownable(initialOwner) {
        _baseTokenURI = baseTokenURI;
        mintingEnabled = false;
    }


    function mint(uint256 amount)
        external
        payable
        whenNotPaused
        onlyWhenMintingEnabled
        validMintAmount(amount)
        supplyAvailable(amount)
        walletMintLimit(msg.sender, amount)
        sufficientPayment(amount)
        nonReentrant
    {
        _processMint(msg.sender, amount);
    }


    function ownerMint(address to, uint256 amount)
        external
        onlyOwner
        validMintAmount(amount)
        supplyAvailable(amount)
    {
        _processMint(to, amount);
    }


    function _processMint(address to, uint256 amount) private {
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _getNextTokenId();
            _safeMint(to, tokenId);
            emit TokenMinted(to, tokenId);
        }

        _mintedPerWallet[to] += amount;
    }


    function _getNextTokenId() private returns (uint256) {
        _currentTokenId++;
        return _currentTokenId;
    }


    function toggleMinting() external onlyOwner {
        mintingEnabled = !mintingEnabled;
        emit MintingStatusChanged(mintingEnabled);
    }


    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function withdrawFunds() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");

        emit FundsWithdrawn(owner(), balance);
    }


    function getMintedCount(address wallet) external view returns (uint256) {
        return _mintedPerWallet[wallet];
    }


    function getCurrentSupply() external view returns (uint256) {
        return _currentTokenId;
    }


    function isAvailableForMint(uint256 amount) external view returns (bool) {
        return _currentTokenId + amount <= MAX_SUPPLY;
    }


    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, tokenId.toString()))
            : "";
    }


    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }


    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable, ERC721Pausable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }


    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }


    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
