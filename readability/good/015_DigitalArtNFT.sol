
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract DigitalArtNFT is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    Counters.Counter private _tokenIdCounter;


    uint256 public constant MAX_SUPPLY = 10000;


    uint256 public mintPrice = 0.01 ether;


    uint256 public constant MAX_MINT_PER_ADDRESS = 10;


    bool public isPaused = false;


    mapping(address => uint256) public addressMintCount;


    mapping(uint256 => address) public tokenCreator;


    event NFTMinted(address indexed to, uint256 indexed tokenId, string tokenURI);


    event PriceUpdated(uint256 oldPrice, uint256 newPrice);


    event PauseStatusChanged(bool isPaused);


    constructor(address initialOwner) ERC721("Digital Art NFT", "DANFT") {
        _transferOwnership(initialOwner);
    }


    modifier whenNotPaused() {
        require(!isPaused, "Contract is paused");
        _;
    }


    modifier tokenExists(uint256 tokenId) {
        require(_exists(tokenId), "Token does not exist");
        _;
    }


    function mintNFT(address to, string memory tokenURI)
        public
        payable
        whenNotPaused
        nonReentrant
    {
        require(to != address(0), "Cannot mint to zero address");
        require(bytes(tokenURI).length > 0, "Token URI cannot be empty");
        require(msg.value >= mintPrice, "Insufficient payment");
        require(_tokenIdCounter.current() < MAX_SUPPLY, "Max supply reached");
        require(
            addressMintCount[to] < MAX_MINT_PER_ADDRESS,
            "Max mint per address exceeded"
        );


        _tokenIdCounter.increment();
        uint256 newTokenId = _tokenIdCounter.current();


        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, tokenURI);


        addressMintCount[to]++;
        tokenCreator[newTokenId] = msg.sender;


        if (msg.value > mintPrice) {
            payable(msg.sender).transfer(msg.value - mintPrice);
        }

        emit NFTMinted(to, newTokenId, tokenURI);
    }


    function batchMintNFT(address to, string[] memory tokenURIs)
        public
        onlyOwner
        whenNotPaused
    {
        require(to != address(0), "Cannot mint to zero address");
        require(tokenURIs.length > 0, "Token URIs array cannot be empty");
        require(
            _tokenIdCounter.current() + tokenURIs.length <= MAX_SUPPLY,
            "Batch mint would exceed max supply"
        );

        for (uint256 i = 0; i < tokenURIs.length; i++) {
            require(bytes(tokenURIs[i]).length > 0, "Token URI cannot be empty");

            _tokenIdCounter.increment();
            uint256 newTokenId = _tokenIdCounter.current();

            _safeMint(to, newTokenId);
            _setTokenURI(newTokenId, tokenURIs[i]);

            tokenCreator[newTokenId] = msg.sender;

            emit NFTMinted(to, newTokenId, tokenURIs[i]);
        }

        addressMintCount[to] += tokenURIs.length;
    }


    function updateTokenURI(uint256 tokenId, string memory newTokenURI)
        public
        tokenExists(tokenId)
    {
        require(
            msg.sender == tokenCreator[tokenId] || msg.sender == owner(),
            "Only creator or owner can update token URI"
        );
        require(bytes(newTokenURI).length > 0, "Token URI cannot be empty");

        _setTokenURI(tokenId, newTokenURI);
    }


    function setMintPrice(uint256 newPrice) public onlyOwner {
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;
        emit PriceUpdated(oldPrice, newPrice);
    }


    function setPauseStatus(bool paused) public onlyOwner {
        isPaused = paused;
        emit PauseStatusChanged(paused);
    }


    function withdrawFunds() public onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        payable(owner()).transfer(balance);
    }


    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }


    function getTokenCreator(uint256 tokenId)
        public
        view
        tokenExists(tokenId)
        returns (address)
    {
        return tokenCreator[tokenId];
    }


    function canMintMore(address account) public view returns (bool) {
        return addressMintCount[account] < MAX_MINT_PER_ADDRESS;
    }


    function getRemainingMintCount(address account) public view returns (uint256) {
        if (addressMintCount[account] >= MAX_MINT_PER_ADDRESS) {
            return 0;
        }
        return MAX_MINT_PER_ADDRESS - addressMintCount[account];
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
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);


        delete tokenCreator[tokenId];
    }
}
