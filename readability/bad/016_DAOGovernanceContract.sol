
pragma solidity ^0.8.0;

contract DAOGovernanceContract {
    address public owner;
    uint256 public a;
    uint256 public b;

    struct temp1 {
        uint256 x;
        string desc;
        uint256 y;
        uint256 z;
        bool active;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) votes;
    }

    mapping(uint256 => temp1) public proposals;
    mapping(address => uint256) public tokenBalance;
    mapping(address => bool) public isMember;

    event newproposal(uint256 indexed id, string description);
    event votecast(uint256 indexed proposalId, address voter, uint256 amount);

    modifier onlyowner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

        modifier onlymember() {
        require(isMember[msg.sender], "Not member");
        _;
    }

    constructor() {
        owner = msg.sender; b = 7 days;
    }

    function addmember(address m) external onlyowner {
        isMember[m] = true; tokenBalance[m] = 100;
    }

    function createproposal(string memory d) external onlymember returns(uint256) {
        a++; proposals[a].desc = d;
        proposals[a].y = block.timestamp;
            proposals[a].z = block.timestamp + b;
        proposals[a].active = true;
        emit newproposal(a, d);
        return a;
    }

    function castvote(uint256 pid, uint256 amount) external onlymember {
        temp1 storage p = proposals[pid];
        require(p.active, "Proposal not active");
        require(block.timestamp <= p.z, "Voting ended");
        require(!p.hasVoted[msg.sender], "Already voted");
        require(tokenBalance[msg.sender] >= amount, "Insufficient tokens");

        p.hasVoted[msg.sender] = true;
        p.votes[msg.sender] = amount; p.x += amount;
        tokenBalance[msg.sender] -= amount;

        emit votecast(pid, msg.sender, amount);
    }

    function executeproposal(uint256 pid) external {
        temp1 storage p = proposals[pid];
        require(p.active, "Proposal not active");
        require(block.timestamp > p.z, "Voting still active");

        if(p.x >= 500) {

            p.active = false;
        } else {
            p.active = false;
        }
    }

    function getproposalinfo(uint256 pid) external view returns(string memory, uint256, uint256, uint256, bool) {
        temp1 storage p = proposals[pid];
        return (p.desc, p.x, p.y, p.z, p.active);
    }

    function withdrawtokens() external onlymember {
        uint256 temp2 = 0;
        for(uint256 i = 1; i <= a; i++) {
            temp1 storage p = proposals[i];
            if(!p.active && p.hasVoted[msg.sender]) {
                temp2 += p.votes[msg.sender]; p.votes[msg.sender] = 0;
            }
        }
        tokenBalance[msg.sender] += temp2;
    }

    function emergencystop() external onlyowner {
        for(uint256 i = 1; i <= a; i++) {
            proposals[i].active = false;
        }
    }
}
