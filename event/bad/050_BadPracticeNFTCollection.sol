
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BadPracticeNFTCollection is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;
    bool public mintingActive = false;
    string private _baseTokenURI;

    mapping(address => uint256) public mintedCount;
    mapping(uint256 => string) private _tokenURIs;


    event TokenMinted(address minter, uint256 tokenId, uint256 price);
    event PriceChanged(uint256 oldPrice, uint256 newPrice);
    event BaseURIChanged(string newBaseURI);


    error Error1();
    error Error2();
    error Error3();

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address to) external payable {

        require(mintingActive);
        require(msg.value >= mintPrice);
        require(_tokenIdCounter.current() < maxSupply);
        require(mintedCount[to] < 5);

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        mintedCount[to]++;
        _safeMint(to, tokenId);




        emit TokenMinted(to, tokenId, msg.value);
    }

    function batchMint(address to, uint256 quantity) external payable {

        require(mintingActive);
        require(quantity > 0 && quantity <= 10);
        require(msg.value >= mintPrice * quantity);
        require(_tokenIdCounter.current() + quantity <= maxSupply);
        require(mintedCount[to] + quantity <= 5);

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(to, tokenId);
            emit TokenMinted(to, tokenId, mintPrice);
        }

        mintedCount[to] += quantity;

    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;
        emit PriceChanged(oldPrice, newPrice);
    }

    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {

        require(newMaxSupply >= _tokenIdCounter.current());
        maxSupply = newMaxSupply;

    }

    function toggleMinting() external onlyOwner {
        mintingActive = !mintingActive;

    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
        emit BaseURIChanged(baseURI);
    }

    function setTokenURI(uint256 tokenId, string memory tokenURI) external onlyOwner {

        require(_exists(tokenId));
        _tokenURIs[tokenId] = tokenURI;

    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;

        require(balance > 0);

        (bool success, ) = payable(owner()).call{value: balance}("");

        require(success);

    }

    function burn(uint256 tokenId) external {

        require(_isApprovedOrOwner(_msgSender(), tokenId));
        _burn(tokenId);

    }

    function transferOwnership(address newOwner) public override onlyOwner {

        require(newOwner != address(0));
        super.transferOwnership(newOwner);

    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {

        require(_exists(tokenId));

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        if (bytes(base).length == 0) {
            return _tokenURI;
        }

        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
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
        return _exists(tokenId);
    }
}
