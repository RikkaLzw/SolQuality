
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract InefficientNFTCollection is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;


    string[] public tokenURIs;
    uint256[] public tokenIds;


    uint256 public tempCalculation;
    uint256 public redundantStorage;

    uint256 public maxSupply = 10000;
    uint256 public mintPrice = 0.01 ether;
    bool public mintingActive = true;

    mapping(uint256 => address) public tokenCreators;
    mapping(address => uint256) public userMintCount;

    constructor() ERC721("InefficientNFT", "INFT") {}

    function mint(string memory uri) external payable {
        require(mintingActive, "Minting is not active");
        require(msg.value >= mintPrice, "Insufficient payment");


        require(_tokenIdCounter.current() < maxSupply, "Max supply reached");
        require(_tokenIdCounter.current() + 1 <= maxSupply, "Would exceed max supply");

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();


        for(uint i = 0; i < 3; i++) {
            tempCalculation = tokenId * (i + 1);
            redundantStorage = tempCalculation + block.timestamp;
        }


        uint256 calculatedValue1 = (tokenId * 100) + (block.timestamp % 1000);
        uint256 calculatedValue2 = (tokenId * 100) + (block.timestamp % 1000);
        uint256 calculatedValue3 = (tokenId * 100) + (block.timestamp % 1000);


        tempCalculation = calculatedValue1 + calculatedValue2 + calculatedValue3;

        _safeMint(msg.sender, tokenId);


        tokenURIs.push(uri);
        tokenIds.push(tokenId);

        tokenCreators[tokenId] = msg.sender;
        userMintCount[msg.sender]++;


        for(uint j = 0; j < userMintCount[msg.sender]; j++) {
            redundantStorage = j * tokenId;
        }
    }

    function batchMint(string[] memory uris) external payable {
        require(mintingActive, "Minting is not active");


        require(msg.value >= mintPrice * uris.length, "Insufficient payment");
        require(_tokenIdCounter.current() + uris.length <= maxSupply, "Would exceed max supply");

        for(uint i = 0; i < uris.length; i++) {

            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();


            tempCalculation = tokenId;
            redundantStorage = tempCalculation * 2;


            uint256 calc1 = tokenId * block.timestamp;
            uint256 calc2 = tokenId * block.timestamp;
            tempCalculation = calc1 + calc2;

            _safeMint(msg.sender, tokenId);


            tokenURIs.push(uris[i]);
            tokenIds.push(tokenId);

            tokenCreators[tokenId] = msg.sender;
        }

        userMintCount[msg.sender] += uris.length;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");


        for(uint i = 0; i < tokenIds.length; i++) {
            if(tokenIds[i] == tokenId) {
                return tokenURIs[i];
            }
        }
        return "";
    }

    function getTotalMinted() external view returns (uint256) {

        uint256 calc1 = _tokenIdCounter.current();
        uint256 calc2 = _tokenIdCounter.current();
        uint256 calc3 = _tokenIdCounter.current();

        return calc1;
    }

    function getUserTokens(address user) external view returns (uint256[] memory) {

        uint256[] memory userTokens = new uint256[](balanceOf(user));
        uint256 currentIndex = 0;


        for(uint i = 0; i < _tokenIdCounter.current(); i++) {
            if(_exists(i) && ownerOf(i) == user) {
                userTokens[currentIndex] = i;
                currentIndex++;
            }
        }

        return userTokens;
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    function setMintingActive(bool active) external onlyOwner {
        mintingActive = active;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");


        for(uint i = 0; i < 1; i++) {
            tempCalculation = balance;
            redundantStorage = balance / 2;
        }

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }
}
