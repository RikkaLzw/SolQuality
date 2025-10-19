
pragma solidity ^0.8.0;

contract voting_governance_contract {
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

    event temp_event1(uint256 indexed x, address indexed s);
    event temp_event2(uint256 indexed x, address indexed voter, bool support);
    event temp_event3(uint256 indexed x);

    modifier only_owner() { require(msg.sender == a, "Not owner"); _; }
    modifier valid_proposal(uint256 _x) { require(_x > 0 && _x <= b, "Invalid proposal"); _; }

    constructor() { a = msg.sender; u[msg.sender] = 1000; }

    function set_voting_power(address _addr, uint256 _power) external only_owner {
        u[_addr] = _power;
    }

    function create_proposal(string memory _desc) external returns (uint256) {
        require(u[msg.sender] > 0, "No voting power");
        b++; uint256 temp_id = b;
        t[temp_id] = temp1({
            x: temp_id,
            y: _desc,
            z: 0,
            w: 0,
            q: block.timestamp + c,
            r: false,
            s: msg.sender
        });
        emit temp_event1(temp_id, msg.sender);
        return temp_id;
    }

    function cast_vote(uint256 _x, bool _support) external valid_proposal(_x) {
        require(u[msg.sender] > 0, "No voting power");
        require(!v[_x][msg.sender], "Already voted");
        require(block.timestamp < t[_x].q, "Voting ended");

        v[_x][msg.sender] = true;
        if (_support) { t[_x].z += u[msg.sender]; } else { t[_x].w += u[msg.sender]; }

        emit temp_event2(_x, msg.sender, _support);
    }

    function execute_proposal(uint256 _x) external valid_proposal(_x) {
        require(block.timestamp >= t[_x].q, "Voting not ended");
        require(!t[_x].r, "Already executed");
        require(t[_x].z > t[_x].w, "Proposal rejected");

        t[_x].r = true;
        emit temp_event3(_x);
    }

    function get_proposal_info(uint256 _x) external view valid_proposal(_x) returns (
        string memory desc,
        uint256 votes_for,
        uint256 votes_against,
        uint256 end_time,
        bool executed,
        address proposer
    ) {
        temp1 storage p = t[_x];
        return (p.y, p.z, p.w, p.q, p.r, p.s);
    }

    function get_voting_power(address _addr) external view returns (uint256) { return u[_addr]; }

    function has_voted(uint256 _x, address _addr) external view returns (bool) { return v[_x][_addr]; }

    function get_proposal_count() external view returns (uint256) { return b; }

    function change_voting_period(uint256 _new_period) external only_owner { c = _new_period; }

    function transfer_ownership(address _new_owner) external only_owner {
        require(_new_owner != address(0), "Invalid address"); a = _new_owner;
    }
}
