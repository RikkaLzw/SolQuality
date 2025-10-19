
pragma solidity ^0.8.0;

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
    uint256 public constant MAX_MINT_PER_TX = 5;
    uint256 public constant MAX_MINT_PER_WALLET = 20;


    Counters.Counter private _tokenIdCounter;
    uint256 public mintPrice = 0.08 ether;
    string private _baseTokenURI;
    bool public publicSaleActive = false;
    bool public whitelistSaleActive = false;


    mapping(address => bool) public whitelist;
    mapping(address => uint256) public walletMintCount;


    event MintPriceUpdated(uint256 newPrice);
    event BaseURIUpdated(string newBaseURI);
    event WhitelistUpdated(address indexed user, bool status);
    event SaleStateUpdated(bool publicSale, bool whitelistSale);


    modifier validMintAmount(uint256 _amount) {
        require(_amount > 0 && _amount <= MAX_MINT_PER_TX, "Invalid mint amount");
        _;
    }

    modifier supplyAvailable(uint256 _amount) {
        require(_tokenIdCounter.current() + _amount <= MAX_SUPPLY, "Exceeds max supply");
        _;
    }

    modifier walletLimitCheck(address _wallet, uint256 _amount) {
        require(
            walletMintCount[_wallet] + _amount <= MAX_MINT_PER_WALLET,
            "Exceeds wallet mint limit"
        );
        _;
    }

    modifier correctPayment(uint256 _amount) {
        require(msg.value >= mintPrice * _amount, "Insufficient payment");
        _;
    }

    modifier saleActive(bool _isWhitelistSale) {
        if (_isWhitelistSale) {
            require(whitelistSaleActive, "Whitelist sale not active");
            require(whitelist[msg.sender], "Not whitelisted");
        } else {
            require(publicSaleActive, "Public sale not active");
        }
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initialBaseURI
    ) ERC721(_name, _symbol) {
        _baseTokenURI = _initialBaseURI;

        _tokenIdCounter.increment();
    }


    function publicMint(uint256 _amount)
        external
        payable
        nonReentrant
        whenNotPaused
        validMintAmount(_amount)
        supplyAvailable(_amount)
        walletLimitCheck(msg.sender, _amount)
        correctPayment(_amount)
        saleActive(false)
    {
        _executeMint(msg.sender, _amount);
    }

    function whitelistMint(uint256 _amount)
        external
        payable
        nonReentrant
        whenNotPaused
        validMintAmount(_amount)
        supplyAvailable(_amount)
        walletLimitCheck(msg.sender, _amount)
        correctPayment(_amount)
        saleActive(true)
    {
        _executeMint(msg.sender, _amount);
    }


    function ownerMint(address _to, uint256 _amount)
        external
        onlyOwner
        supplyAvailable(_amount)
    {
        _executeMint(_to, _amount);
    }

    function setMintPrice(uint256 _newPrice) external onlyOwner {
        mintPrice = _newPrice;
        emit MintPriceUpdated(_newPrice);
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        _baseTokenURI = _newBaseURI;
        emit BaseURIUpdated(_newBaseURI);
    }

    function setSaleState(bool _publicSale, bool _whitelistSale) external onlyOwner {
        publicSaleActive = _publicSale;
        whitelistSaleActive = _whitelistSale;
        emit SaleStateUpdated(_publicSale, _whitelistSale);
    }

    function updateWhitelist(address[] calldata _users, bool _status) external onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            whitelist[_users[i]] = _status;
            emit WhitelistUpdated(_users[i], _status);
        }
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


    function _executeMint(address _to, uint256 _amount) internal {
        walletMintCount[_to] += _amount;

        for (uint256 i = 0; i < _amount; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(_to, tokenId);
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }


    function totalSupply() public view override returns (uint256) {
        return _tokenIdCounter.current() - 1;
    }

    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function getWalletMintCount(address _wallet) external view returns (uint256) {
        return walletMintCount[_wallet];
    }

    function isWhitelisted(address _user) external view returns (bool) {
        return whitelist[_user];
    }


    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
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
