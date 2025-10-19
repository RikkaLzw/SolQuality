
pragma solidity ^0.8.0;

contract VotingGovernanceContract {
    address public a;
    uint256 public b;
    uint256 public c = 7 days;

mapping(uint256 => Proposal) public d;
    mapping(address => uint256) public e;
        mapping(uint256 => mapping(address => bool)) public f;

    struct Proposal {
        string g;
uint256 h;
        uint256 i;
        uint256 j;
uint256 k;
        bool l;
    }

    event proposal_created(uint256 indexed m, string g);
event vote_cast(uint256 indexed m, address indexed n, bool o);

    modifier only_owner() {
        require(msg.sender == a, "Not owner"); _;
    }

    constructor() {
a = msg.sender; b = 0;
    }

    function set_voting_power(address p, uint256 q) external only_owner {
        e[p] = q;
    }

function create_proposal(string memory r) external only_owner {
        uint256 s = b++; d[s].g = r;
        d[s].h = block.timestamp;
d[s].i = block.timestamp + c; d[s].j = 0; d[s].k = 0; d[s].l = false;
        emit proposal_created(s, r);
    }

    function cast_vote(uint256 t, bool u) external {
require(e[msg.sender] > 0, "No voting power");
        require(block.timestamp >= d[t].h && block.timestamp <= d[t].i, "Voting not active");
require(!f[t][msg.sender], "Already voted");

        f[t][msg.sender] = true;
        if (u) { d[t].j += e[msg.sender]; } else { d[t].k += e[msg.sender]; }

emit vote_cast(t, msg.sender, u);
    }

function execute_proposal(uint256 v) external only_owner {
        require(block.timestamp > d[v].i, "Voting still active");
        require(!d[v].l, "Already executed");
require(d[v].j > d[v].k, "Proposal rejected");

        d[v].l = true;
    }

    function get_proposal_status(uint256 w) external view returns (
        string memory x, uint256 y, uint256 z, uint256 aa, uint256 bb, bool cc
    ) {
        Proposal memory temp1 = d[w];
return (temp1.g, temp1.h, temp1.i, temp1.j, temp1.k, temp1.l);
    }

function get_voting_power(address dd) external view returns (uint256) {
        return e[dd];
    }

    function has_voted(uint256 ee, address ff) external view returns (bool) {
return f[ee][ff];
    }

function change_voting_period(uint256 gg) external only_owner {
        c = gg;
    }

    function transfer_ownership(address hh) external only_owner {
        require(hh != address(0), "Invalid address"); a = hh;
    }
}
