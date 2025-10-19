
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
    string private _baseTokenURI;

    mapping(address => uint256) public mintedByAddress;
    mapping(uint256 => bool) public tokenExists;


    event TokenMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event MintPriceUpdated(uint256 indexed oldPrice, uint256 indexed newPrice);
    event MintingStatusChanged(bool indexed isActive);
    event MaxMintsPerAddressUpdated(uint256 indexed oldLimit, uint256 indexed newLimit);
    event BaseURIUpdated(string indexed newBaseURI);
    event TokenURIUpdated(uint256 indexed tokenId, string newTokenURI);
    event WithdrawalCompleted(address indexed owner, uint256 indexed amount);

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) ERC721(name, symbol) {
        _baseTokenURI = baseTokenURI;
        emit BaseURIUpdated(baseTokenURI);
    }

    modifier onlyWhenMintingActive() {
        if (!mintingActive) {
            revert("Minting is currently not active");
        }
        _;
    }

    modifier validTokenId(uint256 tokenId) {
        if (!tokenExists[tokenId]) {
            revert("Token does not exist");
        }
        _;
    }

    function mint(address to, string memory tokenURI)
        external
        payable
        nonReentrant
        onlyWhenMintingActive
    {
        if (to == address(0)) {
            revert("Cannot mint to zero address");
        }

        if (msg.value < mintPrice) {
            revert("Insufficient payment for minting");
        }

        if (_tokenIdCounter.current() >= MAX_SUPPLY) {
            revert("Maximum supply reached");
        }

        if (mintedByAddress[to] >= maxMintsPerAddress) {
            revert("Maximum mints per address exceeded");
        }

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
            if (!success) {
                revert("Failed to refund excess payment");
            }
        }
    }

    function ownerMint(address to, string memory tokenURI)
        external
        onlyOwner
        nonReentrant
    {
        if (to == address(0)) {
            revert("Cannot mint to zero address");
        }

        if (_tokenIdCounter.current() >= MAX_SUPPLY) {
            revert("Maximum supply reached");
        }

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        tokenExists[tokenId] = true;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);

        emit TokenMinted(to, tokenId, tokenURI);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;
        emit MintPriceUpdated(oldPrice, newPrice);
    }

    function setMaxMintsPerAddress(uint256 newLimit) external onlyOwner {
        if (newLimit == 0) {
            revert("Mint limit cannot be zero");
        }

        uint256 oldLimit = maxMintsPerAddress;
        maxMintsPerAddress = newLimit;
        emit MaxMintsPerAddressUpdated(oldLimit, newLimit);
    }

    function setMintingActive(bool active) external onlyOwner {
        mintingActive = active;
        emit MintingStatusChanged(active);
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function setTokenURI(uint256 tokenId, string memory newTokenURI)
        external
        onlyOwner
        validTokenId(tokenId)
    {
        _setTokenURI(tokenId, newTokenURI);
        emit TokenURIUpdated(tokenId, newTokenURI);
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert("No funds available for withdrawal");
        }

        (bool success, ) = payable(owner()).call{value: balance}("");
        if (!success) {
            revert("Withdrawal failed");
        }

        emit WithdrawalCompleted(owner(), balance);
    }

    function burn(uint256 tokenId) external validTokenId(tokenId) {
        if (ownerOf(tokenId) != msg.sender && getApproved(tokenId) != msg.sender && !isApprovedForAll(ownerOf(tokenId), msg.sender)) {
            revert("Caller is not owner nor approved");
        }

        tokenExists[tokenId] = false;
        _burn(tokenId);
    }


    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - _tokenIdCounter.current();
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
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
}
