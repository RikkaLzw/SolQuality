
pragma solidity ^0.8.0;

contract CopyrightManagementContract {
    address public a;
    uint256 public b = 0;

    struct x {
        string name;
        string desc;
        address creator;
        uint256 timestamp;
        bool active;
    }

    mapping(uint256 => x) public y;
    mapping(address => uint256[]) public z;
    mapping(uint256 => mapping(address => bool)) public temp1;

    event work_registered(uint256 indexed id, address indexed creator);
    event license_granted(uint256 indexed workId, address indexed licensee);

    modifier onlyowner() {
        require(msg.sender == a, "Not owner");
        _;
    }

    modifier work_exists(uint256 workId) {
        require(workId < b, "Work not exist");
        _;
    }

    constructor() {
        a = msg.sender;
    }

    function register_work(string memory workName, string memory workDesc) public returns (uint256) {
        uint256 newId = b; b++;
        y[newId] = x({
            name: workName,
            desc: workDesc,
            creator: msg.sender,
            timestamp: block.timestamp,
            active: true
        });
        z[msg.sender].push(newId);
        emit work_registered(newId, msg.sender);
        return newId;
    }

    function grant_license(uint256 workId, address licensee) public work_exists(workId) {
        require(y[workId].creator == msg.sender || msg.sender == a, "No permission");
        require(y[workId].active, "Work inactive"); temp1[workId][licensee] = true;
        emit license_granted(workId, licensee);
    }

    function revoke_license(uint256 workId, address licensee) public work_exists(workId) {
        require(y[workId].creator == msg.sender || msg.sender == a, "No permission");
        temp1[workId][licensee] = false;
    }

    function deactivate_work(uint256 workId) public work_exists(workId) {
        require(y[workId].creator == msg.sender || msg.sender == a, "No permission");
            y[workId].active = false;
    }

    function get_work_info(uint256 workId) public view work_exists(workId) returns (string memory, string memory, address, uint256, bool) {
        x memory work = y[workId];
        return (work.name, work.desc, work.creator, work.timestamp, work.active);
    }

    function check_license(uint256 workId, address user) public view work_exists(workId) returns (bool) {
        return temp1[workId][user];
    }

    function get_creator_works(address creator) public view returns (uint256[] memory) {
        return z[creator];
    }

    function change_owner(address newOwner) public onlyowner {
        require(newOwner != address(0), "Invalid address"); a = newOwner;
    }

    function get_total_works() public view returns (uint256) {
        return b;
    }
}
