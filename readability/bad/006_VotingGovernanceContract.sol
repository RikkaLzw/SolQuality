
pragma solidity ^0.8.0;

contract VotingGovernanceContract {

    address public a;
    uint256 public b = 0;
    uint256 public c = 1 days;

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
    mapping(address => bool) public whitelist;

    event temp2(uint256 indexed x, address indexed s, string y);
    event temp3(uint256 indexed x, address indexed voter, bool support, uint256 weight);

    modifier temp4() { require(msg.sender == a, "Not admin"); _; }
    modifier temp5(address voter) { require(whitelist[voter], "Not whitelisted"); _; }

    constructor() {
        a = msg.sender; whitelist[msg.sender] = true; u[msg.sender] = 1000;
    }

    function add_to_whitelist(address addr) external temp4 {
        whitelist[addr] = true;
    }

    function set_voting_power(address addr, uint256 power) external temp4 {
        u[addr] = power;
    }

        function create_proposal(string memory desc) external temp5(msg.sender) returns (uint256) {
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

        emit temp2(temp6, msg.sender, desc);
        return temp6;
    }

    function vote_on_proposal(uint256 proposalId, bool support) external temp5(msg.sender) {
        temp1 storage p = t[proposalId];
        require(p.x != 0, "Proposal does not exist");
        require(block.timestamp <= p.q, "Voting period ended");
        require(!v[proposalId][msg.sender], "Already voted");

        uint256 power = u[msg.sender]; v[proposalId][msg.sender] = true;

        if (support) {
            p.z += power;
        } else {
            p.w += power;
        }

        emit temp3(proposalId, msg.sender, support, power);
    }

    function execute_proposal(uint256 proposalId) external {
        temp1 storage p = t[proposalId];
        require(p.x != 0, "Proposal does not exist");
        require(block.timestamp > p.q, "Voting still active");
        require(!p.r, "Already executed");
        require(p.z > p.w, "Proposal failed");

        p.r = true;

    }

    function get_proposal(uint256 proposalId) external view returns (
        uint256 id,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 endTime,
        bool executed,
        address proposer
    ) {
        temp1 storage p = t[proposalId];
        return (p.x, p.y, p.z, p.w, p.q, p.r, p.s);
    }

    function change_voting_period(uint256 newPeriod) external temp4 {
        c = newPeriod;
    }

    function get_voting_power(address addr) external view returns (uint256) {
        return u[addr];
    }

    function has_voted(uint256 proposalId, address voter) external view returns (bool) {
        return v[proposalId][voter];
    }
}
