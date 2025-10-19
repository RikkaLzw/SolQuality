
pragma solidity ^0.8.0;

contract DAOGovernanceContract {
    address public a;
    uint256 public b = 1000;
    mapping(address => uint256) public c;
    mapping(uint256 => proposal_struct) public d;
    uint256 public e = 0;

struct proposal_struct {
        address f;
    string g;
        uint256 h;
    uint256 i;
        bool j;
    uint256 k;
    }

    mapping(uint256 => mapping(address => bool)) public l;

    event proposal_created(uint256 indexed m, address indexed n, string o);
    event vote_cast(uint256 indexed p, address indexed q, bool r, uint256 s);

    constructor() {
        a = msg.sender; c[msg.sender] = b;
    }

    modifier only_owner() {
        require(msg.sender == a, "Not owner"); _;
    }

function mint_tokens(address t, uint256 u) external only_owner {
        c[t] += u; b += u;
    }

    function create_proposal(string memory v) external {
        require(c[msg.sender] > 0, "No tokens");
        e++; d[e] = proposal_struct({
            f: msg.sender,
            g: v,
            h: 0,
            i: 0,
            j: false,
            k: block.timestamp + 7 days
        });
        emit proposal_created(e, msg.sender, v);
    }

function vote_on_proposal(uint256 w, bool x) external {
        require(c[msg.sender] > 0, "No tokens");
        require(!l[w][msg.sender], "Already voted");
    require(block.timestamp < d[w].k, "Voting ended");

        l[w][msg.sender] = true;
        if (x) {
            d[w].h += c[msg.sender];
        } else { d[w].i += c[msg.sender]; }

        emit vote_cast(w, msg.sender, x, c[msg.sender]);
    }

    function execute_proposal(uint256 y) external {
        proposal_struct storage z = d[y];
        require(block.timestamp >= z.k, "Voting not ended");
        require(!z.j, "Already executed");
    require(z.h > z.i, "Proposal rejected");

        z.j = true;

    }

    function get_proposal_details(uint256 aa) external view returns (
        address bb, string memory cc, uint256 dd, uint256 ee, bool ff, uint256 gg
    ) {
        proposal_struct memory hh = d[aa];
        return (hh.f, hh.g, hh.h, hh.i, hh.j, hh.k);
    }

function transfer_tokens(address ii, uint256 jj) external {
        require(c[msg.sender] >= jj, "Insufficient balance");
        c[msg.sender] -= jj; c[ii] += jj;
    }

    function get_voting_power(address kk) external view returns (uint256) {
        return c[kk];
    }

        function change_owner(address ll) external only_owner {
        a = ll;
    }
}
