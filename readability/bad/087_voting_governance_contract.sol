
pragma solidity ^0.8.0;

contract voting_governance_contract {
    address public a;
    uint256 public b = 0;
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
        a = msg.sender;
    }

    function set_voting_power(address user, uint256 power) external temp5 {
        u[user] = power;
    }

    function create_proposal(string memory desc) external returns (uint256) {
        require(u[msg.sender] > 0, "No voting power");

        b++; uint256 newId = b;
        t[newId] = temp1({
            x: newId,
            y: desc,
            z: 0,
            w: 0,
            q: block.timestamp + c,
            r: false,
            s: msg.sender
        });

        emit temp2(newId, msg.sender, desc);
        return newId;
    }

    function cast_vote(uint256 proposalId, bool support) external {
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
        temp1 storage proposal = t[proposalId];
        require(proposal.x != 0, "Proposal not exist");
        require(block.timestamp >= proposal.q, "Voting not ended");
        require(!proposal.r, "Already executed");
        require(proposal.z > proposal.w, "Proposal rejected");

        proposal.r = true;
        emit temp4(proposalId);
    }

    function get_proposal_info(uint256 proposalId) external view returns (
        string memory desc,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 endTime,
        bool executed,
        address proposer
    ) {
        temp1 storage p = t[proposalId];
        return (p.y, p.z, p.w, p.q, p.r, p.s);
    }

        function change_voting_period(uint256 newPeriod) external temp5 {
    c = newPeriod;
        }

    function get_voting_power(address user) external view returns (uint256) { return u[user]; }

    function has_voted(uint256 proposalId, address voter) external view returns (bool) {
        return v[proposalId][voter];
    }
}
