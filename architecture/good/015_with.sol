
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract PremiumNFTCollection is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    using Counters for Counters.Counter;


    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_MINT_PER_TX = 10;
    uint256 public constant MAX_MINT_PER_WALLET = 50;
    uint256 public constant MINT_PRICE = 0.05 ether;


    Counters.Counter private _tokenIdCounter;
    string private _baseTokenURI;
    bool public mintingEnabled;


    mapping(address => uint256) private _walletMints;


    event MintingStatusChanged(bool enabled);
    event BaseURIUpdated(string newBaseURI);
    event TokenMinted(address indexed to, uint256 indexed tokenId);


    modifier mintingActive() {
        require(mintingEnabled, "Minting is not active");
        _;
    }

    modifier validMintAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= MAX_MINT_PER_TX, "Exceeds max mint per transaction");
        _;
    }

    modifier supplyAvailable(uint256 amount) {
        require(
            _tokenIdCounter.current() + amount <= MAX_SUPPLY,
            "Exceeds maximum supply"
        );
        _;
    }

    modifier walletMintLimit(address wallet, uint256 amount) {
        require(
            _walletMints[wallet] + amount <= MAX_MINT_PER_WALLET,
            "Exceeds max mint per wallet"
        );
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) ERC721(name, symbol) {
        _baseTokenURI = baseTokenURI;
        mintingEnabled = false;
    }


    function mint(uint256 amount)
        external
        payable
        nonReentrant
        whenNotPaused
        mintingActive
        validMintAmount(amount)
        supplyAvailable(amount)
        walletMintLimit(msg.sender, amount)
    {
        require(msg.value >= MINT_PRICE * amount, "Insufficient payment");

        _processMint(msg.sender, amount);


        uint256 excess = msg.value - (MINT_PRICE * amount);
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
    }


    function ownerMint(address to, uint256 amount)
        external
        onlyOwner
        supplyAvailable(amount)
        validMintAmount(amount)
    {
        _processMint(to, amount);
    }


    function _processMint(address to, uint256 amount) internal {
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _walletMints[to]++;

            _safeMint(to, tokenId);
            emit TokenMinted(to, tokenId);
        }
    }


    function setMintingEnabled(bool enabled) external onlyOwner {
        mintingEnabled = enabled;
        emit MintingStatusChanged(enabled);
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        payable(owner()).transfer(balance);
    }


    function totalMinted() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function walletMints(address wallet) external view returns (uint256) {
        return _walletMints[wallet];
    }

    function tokensOfOwner(address owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }

        return tokenIds;
    }


    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
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
