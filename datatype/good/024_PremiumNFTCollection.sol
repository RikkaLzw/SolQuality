
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PremiumNFTCollection is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;


    uint16 public constant MAX_SUPPLY = 10000;


    uint256 public mintPrice = 0.05 ether;


    uint8 public constant MAX_TOKENS_PER_TX = 10;


    bool public saleActive = false;


    mapping(address => bool) public whitelist;


    string private _baseTokenURI;


    address public royaltyReceiver;
    uint16 public royaltyPercentage = 250;


    event TokenMinted(address indexed to, uint256 indexed tokenId);
    event SaleStateChanged(bool active);
    event MintPriceChanged(uint256 newPrice);
    event WhitelistUpdated(address indexed user, bool status);
    event RoyaltyUpdated(address receiver, uint16 percentage);

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI,
        address _royaltyReceiver
    ) ERC721(name, symbol) {
        _baseTokenURI = baseURI;
        royaltyReceiver = _royaltyReceiver;
        _tokenIdCounter.increment();
    }

    modifier onlyValidAmount(uint8 amount) {
        require(amount > 0 && amount <= MAX_TOKENS_PER_TX, "Invalid mint amount");
        _;
    }

    modifier onlyWhenSaleActive() {
        require(saleActive, "Sale is not active");
        _;
    }

    modifier onlyWhenSupplyAvailable(uint8 amount) {
        require(_tokenIdCounter.current() + amount - 1 <= MAX_SUPPLY, "Exceeds max supply");
        _;
    }


    function mint(uint8 amount)
        external
        payable
        nonReentrant
        onlyValidAmount(amount)
        onlyWhenSaleActive
        onlyWhenSupplyAvailable(amount)
    {
        require(msg.value >= mintPrice * amount, "Insufficient payment");

        _mintTokens(msg.sender, amount);
    }


    function whitelistMint(uint8 amount)
        external
        payable
        nonReentrant
        onlyValidAmount(amount)
        onlyWhenSupplyAvailable(amount)
    {
        require(whitelist[msg.sender], "Not whitelisted");
        require(msg.value >= mintPrice * amount, "Insufficient payment");

        _mintTokens(msg.sender, amount);
    }


    function ownerMint(address to, uint8 amount)
        external
        onlyOwner
        onlyValidAmount(amount)
        onlyWhenSupplyAvailable(amount)
    {
        _mintTokens(to, amount);
    }


    function _mintTokens(address to, uint8 amount) internal {
        for (uint8 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(to, tokenId);
            emit TokenMinted(to, tokenId);
            _tokenIdCounter.increment();
        }
    }


    function setTokenURI(uint256 tokenId, string memory uri) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        _setTokenURI(tokenId, uri);
    }


    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }


    function toggleSale() external onlyOwner {
        saleActive = !saleActive;
        emit SaleStateChanged(saleActive);
    }


    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceChanged(newPrice);
    }


    function updateWhitelist(address[] calldata addresses, bool status) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = status;
            emit WhitelistUpdated(addresses[i], status);
        }
    }


    function setRoyaltyInfo(address receiver, uint16 percentage) external onlyOwner {
        require(percentage <= 1000, "Royalty too high");
        royaltyReceiver = receiver;
        royaltyPercentage = percentage;
        emit RoyaltyUpdated(receiver, percentage);
    }


    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }


    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current() - 1;
    }


    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }


    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256 currentIndex = 0;

        for (uint256 i = 1; i < _tokenIdCounter.current(); i++) {
            if (_exists(i) && ownerOf(i) == owner) {
                tokenIds[currentIndex] = i;
                currentIndex++;
            }
        }

        return tokenIds;
    }


    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }


    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "Token does not exist");
        receiver = royaltyReceiver;
        royaltyAmount = (salePrice * royaltyPercentage) / 10000;
    }


    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return interfaceId == 0x2a55205a || super.supportsInterface(interfaceId);
    }
}
