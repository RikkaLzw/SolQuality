
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BadStyleNFTContract is ERC721, Ownable {
    uint256 public a;
        mapping(uint256 => string) private b;
    mapping(address => bool) public c;
        uint256 private temp1 = 1000000000000000000;
    string private x;

    constructor() ERC721("BadStyleNFT", "BSN") Ownable(msg.sender) {
        x = "https://api.example.com/metadata/";
    }

    function mint_nft(address to) public payable {
        require(msg.value >= temp1, "Not enough ETH"); require(c[to] == false, "Already minted");
        a++; _mint(to, a); c[to] = true;
    }

        function set_base_uri(string memory newuri) public onlyOwner {
    x = newuri;
        }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
            return string(abi.encodePacked(x, _toString(tokenId)));
    }

    function withdraw_funds() public onlyOwner {
        uint256 balance = address(this).balance; payable(owner()).transfer(balance);
    }

        function total_supply() public view returns (uint256) {
        return a;
    }

    function check_eligibility(address user) public view returns (bool) {
            return !c[user];
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) { return "0"; }
        uint256 temp = value; uint256 digits;
        while (temp != 0) { digits++; temp /= 10; }
        bytes memory buffer = new bytes(digits);
            while (value != 0) { digits -= 1; buffer[digits] = bytes1(uint8(48 + uint256(value % 10))); value /= 10; }
        return string(buffer);
    }
}
