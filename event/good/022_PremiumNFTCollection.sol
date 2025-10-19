
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
    bool public mintingActive = false;
    bool public revealed = false;
    string public baseTokenURI;
    string public hiddenTokenURI;

    mapping(address => uint256) public mintedByAddress;
    mapping(uint256 => bool) public tokenExists;


    event TokenMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event MintingStatusChanged(bool indexed isActive);
    event MintPriceUpdated(uint256 indexed oldPrice, uint256 indexed newPrice);
    event MaxMintsPerAddressUpdated(uint256 indexed oldLimit, uint256 indexed newLimit);
    event BaseURIUpdated(string indexed newBaseURI);
    event HiddenURIUpdated(string indexed newHiddenURI);
    event CollectionRevealed();
    event TokenBurned(uint256 indexed tokenId, address indexed owner);
    event WithdrawalCompleted(address indexed recipient, uint256 indexed amount);

    constructor(
        string memory name,
        string memory symbol,
        string memory _hiddenTokenURI
    ) ERC721(name, symbol) {
        if (bytes(_hiddenTokenURI).length == 0) {
            revert("Hidden URI cannot be empty");
        }
        hiddenTokenURI = _hiddenTokenURI;
        emit HiddenURIUpdated(_hiddenTokenURI);
    }

    modifier onlyWhenMintingActive() {
        if (!mintingActive) {
            revert("Minting is currently inactive");
        }
        _;
    }

    modifier validTokenId(uint256 tokenId) {
        if (!tokenExists[tokenId]) {
            revert("Token does not exist");
        }
        _;
    }

    function mint(address to, string memory uri)
        external
        payable
        onlyWhenMintingActive
        nonReentrant
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

        if (bytes(uri).length == 0) {
            revert("Token URI cannot be empty");
        }

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        mintedByAddress[to]++;
        tokenExists[tokenId] = true;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit TokenMinted(to, tokenId, uri);


        if (msg.value > mintPrice) {
            uint256 refund = msg.value - mintPrice;
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            if (!success) {
                revert("Failed to refund excess payment");
            }
        }
    }

    function batchMint(address[] calldata recipients, string[] calldata uris)
        external
        onlyOwner
        nonReentrant
    {
        if (recipients.length != uris.length) {
            revert("Recipients and URIs arrays length mismatch");
        }

        if (recipients.length == 0) {
            revert("Cannot batch mint zero tokens");
        }

        if (_tokenIdCounter.current() + recipients.length > MAX_SUPPLY) {
            revert("Batch mint would exceed maximum supply");
        }

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) {
                revert("Cannot mint to zero address in batch");
            }

            if (bytes(uris[i]).length == 0) {
                revert("Token URI cannot be empty in batch");
            }

            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();

            tokenExists[tokenId] = true;

            _safeMint(recipients[i], tokenId);
            _setTokenURI(tokenId, uris[i]);

            emit TokenMinted(recipients[i], tokenId, uris[i]);
        }
    }

    function burn(uint256 tokenId) external validTokenId(tokenId) {
        if (ownerOf(tokenId) != msg.sender && getApproved(tokenId) != msg.sender && !isApprovedForAll(ownerOf(tokenId), msg.sender)) {
            revert("Caller is not owner nor approved for this token");
        }

        address tokenOwner = ownerOf(tokenId);
        tokenExists[tokenId] = false;

        _burn(tokenId);

        emit TokenBurned(tokenId, tokenOwner);
    }

    function setMintingActive(bool active) external onlyOwner {
        if (mintingActive == active) {
            revert("Minting status is already set to this value");
        }

        mintingActive = active;
        emit MintingStatusChanged(active);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;
        emit MintPriceUpdated(oldPrice, newPrice);
    }

    function setMaxMintsPerAddress(uint256 newLimit) external onlyOwner {
        if (newLimit == 0) {
            revert("Max mints per address cannot be zero");
        }

        uint256 oldLimit = maxMintsPerAddress;
        maxMintsPerAddress = newLimit;
        emit MaxMintsPerAddressUpdated(oldLimit, newLimit);
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        if (bytes(newBaseURI).length == 0) {
            revert("Base URI cannot be empty");
        }

        baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function setHiddenURI(string calldata newHiddenURI) external onlyOwner {
        if (bytes(newHiddenURI).length == 0) {
            revert("Hidden URI cannot be empty");
        }

        hiddenTokenURI = newHiddenURI;
        emit HiddenURIUpdated(newHiddenURI);
    }

    function reveal() external onlyOwner {
        if (revealed) {
            revert("Collection is already revealed");
        }

        if (bytes(baseTokenURI).length == 0) {
            revert("Base URI must be set before revealing");
        }

        revealed = true;
        emit CollectionRevealed();
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

    function emergencyWithdraw(address payable recipient) external onlyOwner nonReentrant {
        if (recipient == address(0)) {
            revert("Cannot withdraw to zero address");
        }

        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert("No funds available for emergency withdrawal");
        }

        (bool success, ) = recipient.call{value: balance}("");
        if (!success) {
            revert("Emergency withdrawal failed");
        }

        emit WithdrawalCompleted(recipient, balance);
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        validTokenId(tokenId)
        returns (string memory)
    {
        if (!revealed) {
            return hiddenTokenURI;
        }

        return super.tokenURI(tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
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
