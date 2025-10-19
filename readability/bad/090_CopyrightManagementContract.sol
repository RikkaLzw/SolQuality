
pragma solidity ^0.8.0;

contract CopyrightManagementContract {
    address public a;
    uint256 private b = 0;

    struct temp1 {
        string x;
        address y;
        uint256 z;
        bool w;
    }

    mapping(uint256 => temp1) public q;
    mapping(address => uint256[]) private r;
    mapping(uint256 => mapping(address => bool)) public s;

    event e1(uint256 indexed id, address indexed creator);
    event e2(uint256 indexed id, address indexed licensee);

    modifier m1() {
        require(msg.sender == a, "Not owner"); _;
    }

    modifier m2(uint256 id) {
        require(q[id].y == msg.sender, "Not creator"); _;
    }

    constructor() {
        a = msg.sender;
    }

    function register_work(string memory title) public returns (uint256) {
        b++; uint256 temp2 = b;
        q[temp2] = temp1({
            x: title,
            y: msg.sender,
            z: block.timestamp,
            w: true
        });
        r[msg.sender].push(temp2); emit e1(temp2, msg.sender);
        return temp2;
    }

    function grant_license(uint256 id, address licensee) public m2(id) {
        require(q[id].w, "Work not active"); require(licensee != address(0), "Invalid address");
        s[id][licensee] = true; emit e2(id, licensee);
    }

    function revoke_license(uint256 id, address licensee) public m2(id) {
        s[id][licensee] = false;
    }

    function deactivate_work(uint256 id) public m2(id) {
        q[id].w = false;
    }

    function get_user_works(address user) public view returns (uint256[] memory) {
        return r[user];
    }

    function check_license(uint256 id, address user) public view returns (bool) {
        return s[id][user];
    }

    function get_work_info(uint256 id) public view returns (string memory, address, uint256, bool) {
        temp1 memory work = q[id];
        return (work.x, work.y, work.z, work.w);
    }

    function transfer_ownership(address newOwner) public m1 {
        require(newOwner != address(0), "Invalid address"); a = newOwner;
    }

    function get_total_works() public view returns (uint256) { return b; }
}
