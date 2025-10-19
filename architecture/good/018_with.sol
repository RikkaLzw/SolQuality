
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
    uint256 public constant MAX_MINT_PER_TX = 10;
    uint256 public constant MAX_MINT_PER_WALLET = 50;


    uint256 private _tokenIdCounter;
    uint256 public mintPrice = 0.05 ether;
    string private _baseTokenURI;
    bool public publicMintEnabled = false;


    mapping(address => uint256) private _mintedPerWallet;


    event MintPriceUpdated(uint256 newPrice);
    event BaseURIUpdated(string newBaseURI);
    event PublicMintToggled(bool enabled);
    event BatchMinted(address indexed to, uint256 startTokenId, uint256 quantity);


    modifier validMintAmount(uint256 quantity) {
        require(quantity > 0, "Quantity must be greater than 0");
        require(quantity <= MAX_MINT_PER_TX, "Exceeds max mint per transaction");
        _;
    }

    modifier supplyAvailable(uint256 quantity) {
        require(_tokenIdCounter + quantity <= MAX_SUPPLY, "Exceeds maximum supply");
        _;
    }

    modifier walletMintLimit(address to, uint256 quantity) {
        require(
            _mintedPerWallet[to] + quantity <= MAX_MINT_PER_WALLET,
            "Exceeds max mint per wallet"
        );
        _;
    }

    modifier publicMintActive() {
        require(publicMintEnabled, "Public mint is not active");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI,
        address initialOwner
    ) ERC721(name, symbol) Ownable(initialOwner) {
        _baseTokenURI = baseTokenURI;
        _tokenIdCounter = 1;
    }


    function mint(uint256 quantity)
        external
        payable
        nonReentrant
        whenNotPaused
        publicMintActive
        validMintAmount(quantity)
        supplyAvailable(quantity)
        walletMintLimit(msg.sender, quantity)
    {
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        _executeMint(msg.sender, quantity);


        uint256 excess = msg.value - (mintPrice * quantity);
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
    }


    function ownerMint(address to, uint256 quantity)
        external
        onlyOwner
        nonReentrant
        validMintAmount(quantity)
        supplyAvailable(quantity)
    {
        _executeMint(to, quantity);
    }


    function _executeMint(address to, uint256 quantity) private {
        uint256 startTokenId = _tokenIdCounter;

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter;
            _safeMint(to, tokenId);
            _tokenIdCounter++;
        }

        _mintedPerWallet[to] += quantity;
        emit BatchMinted(to, startTokenId, quantity);
    }


    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceUpdated(newPrice);
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function togglePublicMint() external onlyOwner {
        publicMintEnabled = !publicMintEnabled;
        emit PublicMintToggled(publicMintEnabled);
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

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }


    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json"))
            : "";
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function getMintedCount(address wallet) external view returns (uint256) {
        return _mintedPerWallet[wallet];
    }

    function getRemainingMints(address wallet) external view returns (uint256) {
        return MAX_MINT_PER_WALLET - _mintedPerWallet[wallet];
    }

    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }

    function getRemainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - _tokenIdCounter + 1;
    }


    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable, ERC721Pausable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
