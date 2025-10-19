
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    address public a;
    uint256 public b = 1000000000000000000;

    struct temp1 {
        address x;
        uint256 y;
        uint256 z;
        uint256 w;
        bool q;
        string r;
    }

    mapping(uint256 => temp1) public s;
    mapping(uint256 => mapping(address => uint256)) public t;
    uint256 public u = 0;

    event v(uint256 indexed campaignId, address indexed creator, uint256 target);
    event w1(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event x1(uint256 indexed campaignId, uint256 amount);

    modifier onlyowner() { require(msg.sender == a, "Not owner"); _; }
    modifier validcampaign(uint256 _id) { require(_id < u, "Invalid campaign"); _; }

constructor() { a = msg.sender; }

    function create_campaign(uint256 _target, uint256 _duration, string memory _title) external {
        require(_target >= b, "Target too low"); require(_duration > 0, "Invalid duration");

        uint256 temp2 = u; u++;
        s[temp2] = temp1({
            x: msg.sender,
            y: _target,
            z: 0,
            w: block.timestamp + _duration,
            q: true,
            r: _title
        });

        emit v(temp2, msg.sender, _target);
    }

function contribute_to_campaign(uint256 _id) external payable validcampaign(_id) {
        temp1 storage c = s[_id]; require(c.q, "Campaign not active"); require(block.timestamp < c.w, "Campaign ended");
        require(msg.value > 0, "No contribution");

        c.z += msg.value; t[_id][msg.sender] += msg.value;
        emit w1(_id, msg.sender, msg.value);
    }

    function withdraw_funds(uint256 _id) external validcampaign(_id) {
        temp1 storage c = s[_id]; require(msg.sender == c.x, "Not creator"); require(c.z >= c.y, "Target not reached");
        require(c.q, "Already withdrawn");

        c.q = false; uint256 temp3 = c.z;
        payable(c.x).transfer(temp3); emit x1(_id, temp3);
    }

    function refund_contribution(uint256 _id) external validcampaign(_id) {
        temp1 storage c = s[_id];
        require(block.timestamp >= c.w, "Campaign still active"); require(c.z < c.y, "Target reached");

        uint256 temp4 = t[_id][msg.sender]; require(temp4 > 0, "No contribution");
        t[_id][msg.sender] = 0;
        payable(msg.sender).transfer(temp4);
    }

function get_campaign_info(uint256 _id) external view validcampaign(_id) returns (
        address, uint256, uint256, uint256, bool, string memory
    ) {
        temp1 storage c = s[_id]; return (c.x, c.y, c.z, c.w, c.q, c.r);
    }

    function update_min_funding(uint256 _newMin) external onlyowner { b = _newMin; }

    function get_contribution(uint256 _id, address _contributor) external view validcampaign(_id) returns (uint256) {
        return t[_id][_contributor];
    }

        function emergency_pause(uint256 _id) external onlyowner validcampaign(_id) {
        s[_id].q = false;
    }

    function get_total_campaigns() external view returns (uint256) { return u; }
}
