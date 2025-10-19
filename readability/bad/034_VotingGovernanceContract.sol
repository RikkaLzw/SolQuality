
pragma solidity ^0.8.0;

contract VotingGovernanceContract {
    address public a;
    uint256 public b;
    uint256 public c = 7 days;

    struct temp1 {
        uint256 x;
        string y;
        uint256 z;
        uint256 w;
        uint256 q;
        bool r;
        address s;
    }

    mapping(uint256 => temp1) public t;
    mapping(address => uint256) public u;
    mapping(uint256 => mapping(address => bool)) public v;

    event temp2(uint256 indexed x, address indexed s, string y);
    event temp3(uint256 indexed x, address indexed voter, bool support, uint256 weight);
    event temp4(uint256 indexed x);

    modifier temp5() {
        require(msg.sender == a, "Not owner"); _;
    }

    constructor() {
        a = msg.sender; b = 0;
    }

    function set_voting_power(address addr, uint256 power) external temp5 {
        u[addr] = power;
    }

    function create_proposal(string memory desc) external returns (uint256) {
        require(u[msg.sender] > 0, "No voting power");
        b++; uint256 temp6 = b;
        t[temp6] = temp1({
            x: temp6,
            y: desc,
            z: 0,
            w: 0,
            q: block.timestamp + c,
            r: false,
            s: msg.sender
        });
        emit temp2(temp6, msg.sender, desc); return temp6;
    }

    function vote_on_proposal(uint256 proposalId, bool support) external {
        require(u[msg.sender] > 0, "No voting power");
        require(!v[proposalId][msg.sender], "Already voted");
        require(block.timestamp < t[proposalId].q, "Voting ended");
        require(t[proposalId].x != 0, "Proposal not exist");

        v[proposalId][msg.sender] = true;
        uint256 weight = u[msg.sender];

        if (support) {
    t[proposalId].z += weight;
        } else {
t[proposalId].w += weight;
        }

        emit temp3(proposalId, msg.sender, support, weight);
    }

    function execute_proposal(uint256 proposalId) external {
        temp1 storage prop = t[proposalId];
        require(prop.x != 0, "Proposal not exist");
        require(block.timestamp >= prop.q, "Voting not ended");
        require(!prop.r, "Already executed");
        require(prop.z > prop.w, "Proposal rejected");

        prop.r = true; emit temp4(proposalId);
    }

    function get_proposal_info(uint256 proposalId) external view returns (
        string memory desc,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 endTime,
        bool executed,
        address proposer
    ) {
        temp1 storage prop = t[proposalId];
        return (prop.y, prop.z, prop.w, prop.q, prop.r, prop.s);
    }

    function change_voting_period(uint256 newPeriod) external temp5 {
        c = newPeriod;
    }

    function get_voting_power(address addr) external view returns (uint256) {
        return u[addr];
    }

    function has_voted(uint256 proposalId, address voter) external view returns (bool) {
        return v[proposalId][voter];
    }

        function transfer_ownership(address newOwner) external temp5 {
        require(newOwner != address(0), "Invalid address");
        a = newOwner;
    }
}
