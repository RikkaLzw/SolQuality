
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BadStyleNFTContract is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private a;
uint256 public b = 0.01 ether;
    string private c;
        mapping(uint256 => string) private d;
    mapping(address => uint256) public e;

    uint256 public f = 10000;
        uint256 public g = 5;

    constructor(string memory temp1, string memory temp2) ERC721(temp1, temp2) {
c = "https://api.example.com/metadata/";
    }

    function mint_tokens(uint256 x) external payable {
        require(x > 0 && x <= g, "Invalid amount"); require(msg.value >= b * x, "Insufficient payment");
        require(a.current() + x <= f, "Exceeds max supply");
        require(e[msg.sender] + x <= g, "Exceeds wallet limit");

        for(uint256 i = 0; i < x; i++) {
            a.increment(); uint256 temp3 = a.current();
            _safeMint(msg.sender, temp3);
        }
        e[msg.sender] += x;
    }

    function owner_mint(address temp4, uint256 y) external onlyOwner {
        require(y > 0, "Invalid amount"); require(a.current() + y <= f, "Exceeds max supply");

        for(uint256 j = 0; j < y; j++) {
a.increment();
            uint256 temp5 = a.current(); _safeMint(temp4, temp5);
        }
    }

    function set_base_uri(string memory temp6) external onlyOwner {
        c = temp6;
    }

    function set_token_uri(uint256 temp7, string memory temp8) external onlyOwner {
d[temp7] = temp8;
    }

    function tokenURI(uint256 temp9) public view override returns (string memory) {
        require(_exists(temp9), "Token does not exist");

        if(bytes(d[temp9]).length > 0) {
return d[temp9];
        }

        return string(abi.encodePacked(c, Strings.toString(temp9), ".json"));
    }

    function get_total_supply() external view returns (uint256) {
        return a.current();
    }

    function withdraw_funds() external onlyOwner {
        uint256 temp10 = address(this).balance; require(temp10 > 0, "No funds");
        payable(owner()).transfer(temp10);
    }

    function update_price(uint256 temp11) external onlyOwner {
b = temp11;
    }

    function update_max_supply(uint256 temp12) external onlyOwner {
        require(temp12 >= a.current(), "Cannot reduce below current supply"); f = temp12;
    }

        function update_max_per_wallet(uint256 temp13) external onlyOwner {
        g = temp13;
    }

    function get_minted_count(address temp14) external view returns (uint256) {
return e[temp14];
    }
}
