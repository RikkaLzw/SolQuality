
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
    uint256 public maxMintsPerAddress = 5;
    bool public mintingActive = false;
    bool public revealed = false;
    string private _baseTokenURI;
    string private _hiddenMetadataURI;

    mapping(address => uint256) public mintedByAddress;
    mapping(uint256 => bool) private _tokenExists;


    event TokenMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event MintingStatusChanged(bool indexed isActive);
    event RevealStatusChanged(bool indexed isRevealed);
    event MintPriceUpdated(uint256 indexed oldPrice, uint256 indexed newPrice);
    event MaxMintsPerAddressUpdated(uint256 indexed oldLimit, uint256 indexed newLimit);
    event BaseURIUpdated(string indexed newBaseURI);
    event HiddenMetadataURIUpdated(string indexed newHiddenURI);
    event WithdrawalCompleted(address indexed recipient, uint256 indexed amount);
    event TokenBurned(uint256 indexed tokenId, address indexed owner);


    error MintingNotActive();
    error MaxSupplyExceeded();
    error InsufficientPayment(uint256 required, uint256 provided);
    error MaxMintsPerAddressExceeded(uint256 limit, uint256 attempted);
    error TokenDoesNotExist(uint256 tokenId);
    error WithdrawalFailed();
    error InvalidAddress();
    error InvalidTokenURI();
    error InvalidPrice();
    error InvalidLimit();

    constructor(
        string memory name,
        string memory symbol,
        string memory hiddenMetadataURI
    ) ERC721(name, symbol) {
        if (bytes(hiddenMetadataURI).length == 0) {
            revert InvalidTokenURI();
        }
        _hiddenMetadataURI = hiddenMetadataURI;
    }

    modifier validTokenId(uint256 tokenId) {
        if (!_tokenExists[tokenId]) {
            revert TokenDoesNotExist(tokenId);
        }
        _;
    }

    modifier validAddress(address addr) {
        if (addr == address(0)) {
            revert InvalidAddress();
        }
        _;
    }

    function mint(address to, string memory uri) external payable nonReentrant validAddress(to) {
        if (!mintingActive) {
            revert MintingNotActive();
        }

        uint256 currentSupply = _tokenIdCounter.current();
        if (currentSupply >= MAX_SUPPLY) {
            revert MaxSupplyExceeded();
        }

        if (msg.value < mintPrice) {
            revert InsufficientPayment(mintPrice, msg.value);
        }

        uint256 currentMints = mintedByAddress[to];
        if (currentMints >= maxMintsPerAddress) {
            revert MaxMintsPerAddressExceeded(maxMintsPerAddress, currentMints + 1);
        }

        if (bytes(uri).length == 0) {
            revert InvalidTokenURI();
        }

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        mintedByAddress[to]++;
        _tokenExists[tokenId] = true;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit TokenMinted(to, tokenId, uri);


        if (msg.value > mintPrice) {
            uint256 refund = msg.value - mintPrice;
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            if (!success) {
                revert WithdrawalFailed();
            }
        }
    }

    function ownerMint(address to, string memory uri) external onlyOwner validAddress(to) {
        if (bytes(uri).length == 0) {
            revert InvalidTokenURI();
        }

        uint256 currentSupply = _tokenIdCounter.current();
        if (currentSupply >= MAX_SUPPLY) {
            revert MaxSupplyExceeded();
        }

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _tokenExists[tokenId] = true;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit TokenMinted(to, tokenId, uri);
    }

    function burn(uint256 tokenId) external validTokenId(tokenId) {
        address owner = ownerOf(tokenId);
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender) && getApproved(tokenId) != msg.sender) {
            revert("Caller is not owner nor approved");
        }

        _tokenExists[tokenId] = false;
        _burn(tokenId);

        emit TokenBurned(tokenId, owner);
    }

    function setMintingActive(bool active) external onlyOwner {
        mintingActive = active;
        emit MintingStatusChanged(active);
    }

    function setRevealed(bool _revealed) external onlyOwner {
        revealed = _revealed;
        emit RevealStatusChanged(_revealed);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;
        emit MintPriceUpdated(oldPrice, newPrice);
    }

    function setMaxMintsPerAddress(uint256 newLimit) external onlyOwner {
        if (newLimit == 0) {
            revert InvalidLimit();
        }
        uint256 oldLimit = maxMintsPerAddress;
        maxMintsPerAddress = newLimit;
        emit MaxMintsPerAddressUpdated(oldLimit, newLimit);
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function setHiddenMetadataURI(string memory newHiddenURI) external onlyOwner {
        if (bytes(newHiddenURI).length == 0) {
            revert InvalidTokenURI();
        }
        _hiddenMetadataURI = newHiddenURI;
        emit HiddenMetadataURIUpdated(newHiddenURI);
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        if (!success) {
            revert WithdrawalFailed();
        }

        emit WithdrawalCompleted(owner(), balance);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) validTokenId(tokenId) returns (string memory) {
        if (!revealed) {
            return _hiddenMetadataURI;
        }
        return super.tokenURI(tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _tokenExists[tokenId];
    }

    function tokensOfOwner(address owner) external view validAddress(owner) returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < _tokenIdCounter.current() && currentIndex < tokenCount; i++) {
            if (_tokenExists[i] && ownerOf(i) == owner) {
                tokenIds[currentIndex] = i;
                currentIndex++;
            }
        }

        return tokenIds;
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
