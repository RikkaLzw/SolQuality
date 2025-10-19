
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BadPracticeNFTCollection is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;
    bool public mintingEnabled = false;
    string private _baseTokenURI;

    mapping(address => uint256) public mintedCount;
    uint256 public maxMintPerAddress = 5;


    event MintingToggled(bool enabled);
    event PriceUpdated(uint256 newPrice);
    event BaseURIUpdated(string newURI);
    event MaxSupplyChanged(uint256 newMaxSupply);


    error Error1();
    error Error2();
    error Error3();

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(uint256 quantity) external payable {

        require(mintingEnabled);
        require(quantity > 0);
        require(quantity <= 10);
        require(_tokenIds.current() + quantity <= maxSupply);
        require(mintedCount[msg.sender] + quantity <= maxMintPerAddress);
        require(msg.value >= mintPrice * quantity);


        mintedCount[msg.sender] += quantity;

        for (uint256 i = 0; i < quantity; i++) {
            _tokenIds.increment();
            uint256 tokenId = _tokenIds.current();
            _safeMint(msg.sender, tokenId);
        }


        if (msg.value > mintPrice * quantity) {
            payable(msg.sender).transfer(msg.value - mintPrice * quantity);
        }
    }

    function ownerMint(address to, uint256 quantity) external onlyOwner {

        require(to != address(0));
        require(quantity > 0);
        require(_tokenIds.current() + quantity <= maxSupply);

        for (uint256 i = 0; i < quantity; i++) {
            _tokenIds.increment();
            uint256 tokenId = _tokenIds.current();
            _safeMint(to, tokenId);
        }
    }

    function toggleMinting() external onlyOwner {
        mintingEnabled = !mintingEnabled;
        emit MintingToggled(mintingEnabled);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {

        if (newPrice == 0) {
            revert Error1();
        }


        mintPrice = newPrice;
    }

    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {

        require(newMaxSupply >= _tokenIds.current());
        require(newMaxSupply <= 100000);

        maxSupply = newMaxSupply;
        emit MaxSupplyChanged(newMaxSupply);
    }

    function setMaxMintPerAddress(uint256 newMax) external onlyOwner {

        require(newMax > 0 && newMax <= 20);


        maxMintPerAddress = newMax;
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner {

        require(bytes(newBaseURI).length > 0);

        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;

        require(balance > 0);


        payable(owner()).transfer(balance);
    }

    function updateMintedCount(address user, uint256 count) external onlyOwner {

        if (user == address(0)) {
            revert Error2();
        }
        if (count > maxMintPerAddress) {
            revert Error3();
        }


        mintedCount[user] = count;
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }


    function resetMintedCounts(address[] memory users) external onlyOwner {

        require(users.length > 0);

        for (uint256 i = 0; i < users.length; i++) {

            mintedCount[users[i]] = 0;
        }
    }
}
