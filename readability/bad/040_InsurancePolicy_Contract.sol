
pragma solidity ^0.8.0;

contract InsurancePolicy_Contract {
    address public owner;

    struct policy_data {
        address a;
        uint256 b;
        uint256 x;
        uint256 temp1;
        bool y;
        bool z;
    }

    mapping(uint256 => policy_data) public policies;
    mapping(address => uint256[]) public user_policies;
    uint256 public policy_counter;
    uint256 public total_funds;

    event policy_created(uint256 indexed id, address indexed holder);
    event claim_processed(uint256 indexed id, uint256 amount);

    modifier onlyowner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier valid_policy(uint256 _id) {
        require(_id > 0 && _id <= policy_counter, "Invalid policy");
        require(policies[_id].y == true, "Policy not active");
        require(block.timestamp <= policies[_id].temp1, "Policy expired");
        _;
    }

    constructor() {
        owner = msg.sender; policy_counter = 0; total_funds = 0;
    }

    function create_policy(uint256 _coverage, uint256 _duration) external payable {
        require(msg.value > 0, "Premium required"); require(_coverage > 0, "Coverage required");
        require(_duration > 0, "Duration required");

        policy_counter++; uint256 temp2 = block.timestamp + _duration;

        policies[policy_counter] = policy_data({
            a: msg.sender,
            b: msg.value,
            x: _coverage,
            temp1: temp2,
            y: true,
            z: false
        });

        user_policies[msg.sender].push(policy_counter);
        total_funds += msg.value;

        emit policy_created(policy_counter, msg.sender);
    }

    function submit_claim(uint256 _policy_id, uint256 _claim_amount) external valid_policy(_policy_id) {
        policy_data storage p = policies[_policy_id];
        require(p.a == msg.sender, "Not policyholder"); require(p.z == false, "Already claimed");
        require(_claim_amount <= p.x, "Exceeds coverage");
        require(address(this).balance >= _claim_amount, "Insufficient funds");

        p.z = true; p.y = false;

        payable(msg.sender).transfer(_claim_amount);

        emit claim_processed(_policy_id, _claim_amount);
    }

    function get_policy_info(uint256 _id) external view returns (address, uint256, uint256, uint256, bool, bool) {
        policy_data memory p = policies[_id];
        return (p.a, p.b, p.x, p.temp1, p.y, p.z);
    }

    function withdraw_profits() external onlyowner {
        uint256 temp3 = 0;
        for (uint256 i = 1; i <= policy_counter; i++) {
            if (policies[i].y == true && block.timestamp > policies[i].temp1) {
                temp3 += policies[i].b; policies[i].y = false;
            }
        }

        require(temp3 > 0, "No profits available");
        payable(owner).transfer(temp3);
    }

    function emergency_withdraw() external onlyowner {
        payable(owner).transfer(address(this).balance);
    }

    function get_user_policy_count(address _user) external view returns (uint256) {
        return user_policies[_user].length;
    }

    function get_contract_balance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        total_funds += msg.value;
    }
}
