
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DAOGovernanceContract {
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool cancelled;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voterChoice;
    }

    struct Member {
        bool isActive;
        uint256 votingPower;
        uint256 joinTime;
    }

    IERC20 public governanceToken;
    address public admin;
    uint256 public proposalCount;
    uint256 public votingPeriod;
    uint256 public minimumQuorum;
    uint256 public proposalThreshold;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => Member) public members;
    mapping(address => uint256) public memberProposalCount;

    address[] public memberList;
    uint256 public totalMembers;
    uint256 public totalVotingPower;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint256 choice,
        uint256 votingPower
    );

    event ProposalExecuted(uint256 indexed proposalId, bool success);
    event ProposalCancelled(uint256 indexed proposalId, address indexed canceller);

    event MemberAdded(address indexed member, uint256 votingPower);
    event MemberRemoved(address indexed member);
    event MemberVotingPowerUpdated(address indexed member, uint256 oldPower, uint256 newPower);

    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event VotingPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
    event QuorumUpdated(uint256 oldQuorum, uint256 newQuorum);
    event ProposalThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    modifier onlyAdmin() {
        require(msg.sender == admin, "DAOGovernance: caller is not the admin");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender].isActive, "DAOGovernance: caller is not an active member");
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "DAOGovernance: proposal does not exist");
        _;
    }

    modifier proposalActive(uint256 proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "DAOGovernance: voting has not started");
        require(block.timestamp <= proposal.endTime, "DAOGovernance: voting period has ended");
        require(!proposal.executed, "DAOGovernance: proposal already executed");
        require(!proposal.cancelled, "DAOGovernance: proposal has been cancelled");
        _;
    }

    constructor(
        address _governanceToken,
        uint256 _votingPeriod,
        uint256 _minimumQuorum,
        uint256 _proposalThreshold
    ) {
        require(_governanceToken != address(0), "DAOGovernance: governance token cannot be zero address");
        require(_votingPeriod > 0, "DAOGovernance: voting period must be greater than zero");
        require(_minimumQuorum > 0, "DAOGovernance: minimum quorum must be greater than zero");

        governanceToken = IERC20(_governanceToken);
        admin = msg.sender;
        votingPeriod = _votingPeriod;
        minimumQuorum = _minimumQuorum;
        proposalThreshold = _proposalThreshold;


        members[msg.sender] = Member({
            isActive: true,
            votingPower: 100,
            joinTime: block.timestamp
        });
        memberList.push(msg.sender);
        totalMembers = 1;
        totalVotingPower = 100;

        emit MemberAdded(msg.sender, 100);
    }

    function addMember(address member, uint256 votingPower) external onlyAdmin {
        require(member != address(0), "DAOGovernance: member cannot be zero address");
        require(!members[member].isActive, "DAOGovernance: member already exists");
        require(votingPower > 0, "DAOGovernance: voting power must be greater than zero");

        members[member] = Member({
            isActive: true,
            votingPower: votingPower,
            joinTime: block.timestamp
        });

        memberList.push(member);
        totalMembers++;
        totalVotingPower += votingPower;

        emit MemberAdded(member, votingPower);
    }

    function removeMember(address member) external onlyAdmin {
        require(members[member].isActive, "DAOGovernance: member does not exist");
        require(member != admin, "DAOGovernance: cannot remove admin");

        uint256 memberVotingPower = members[member].votingPower;
        members[member].isActive = false;
        members[member].votingPower = 0;

        totalVotingPower -= memberVotingPower;
        totalMembers--;


        for (uint256 i = 0; i < memberList.length; i++) {
            if (memberList[i] == member) {
                memberList[i] = memberList[memberList.length - 1];
                memberList.pop();
                break;
            }
        }

        emit MemberRemoved(member);
    }

    function updateMemberVotingPower(address member, uint256 newVotingPower) external onlyAdmin {
        require(members[member].isActive, "DAOGovernance: member does not exist");
        require(newVotingPower > 0, "DAOGovernance: voting power must be greater than zero");

        uint256 oldVotingPower = members[member].votingPower;
        members[member].votingPower = newVotingPower;

        totalVotingPower = totalVotingPower - oldVotingPower + newVotingPower;

        emit MemberVotingPowerUpdated(member, oldVotingPower, newVotingPower);
    }

    function createProposal(
        string memory title,
        string memory description
    ) external onlyMember returns (uint256) {
        require(bytes(title).length > 0, "DAOGovernance: proposal title cannot be empty");
        require(bytes(description).length > 0, "DAOGovernance: proposal description cannot be empty");

        uint256 memberVotingPower = members[msg.sender].votingPower;
        require(memberVotingPower >= proposalThreshold, "DAOGovernance: insufficient voting power to create proposal");

        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + votingPeriod;
        newProposal.executed = false;
        newProposal.cancelled = false;

        memberProposalCount[msg.sender]++;

        emit ProposalCreated(proposalId, msg.sender, title, newProposal.startTime, newProposal.endTime);

        return proposalId;
    }

    function vote(uint256 proposalId, uint256 choice) external
        onlyMember
        proposalExists(proposalId)
        proposalActive(proposalId)
    {
        require(choice == 1 || choice == 2, "DAOGovernance: invalid vote choice (1 for yes, 2 for no)");

        Proposal storage proposal = proposals[proposalId];
        require(!proposal.hasVoted[msg.sender], "DAOGovernance: member has already voted");

        uint256 voterPower = members[msg.sender].votingPower;
        proposal.hasVoted[msg.sender] = true;
        proposal.voterChoice[msg.sender] = choice;

        if (choice == 1) {
            proposal.votesFor += voterPower;
        } else {
            proposal.votesAgainst += voterPower;
        }

        emit VoteCast(proposalId, msg.sender, choice, voterPower);
    }

    function executeProposal(uint256 proposalId) external
        proposalExists(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "DAOGovernance: voting period has not ended");
        require(!proposal.executed, "DAOGovernance: proposal already executed");
        require(!proposal.cancelled, "DAOGovernance: proposal has been cancelled");

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        require(totalVotes >= minimumQuorum, "DAOGovernance: quorum not reached");

        proposal.executed = true;
        bool success = proposal.votesFor > proposal.votesAgainst;

        emit ProposalExecuted(proposalId, success);
    }

    function cancelProposal(uint256 proposalId) external
        proposalExists(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer || msg.sender == admin,
            "DAOGovernance: only proposer or admin can cancel proposal"
        );
        require(!proposal.executed, "DAOGovernance: cannot cancel executed proposal");
        require(!proposal.cancelled, "DAOGovernance: proposal already cancelled");

        proposal.cancelled = true;
        emit ProposalCancelled(proposalId, msg.sender);
    }

    function getProposalInfo(uint256 proposalId) external view
        proposalExists(proposalId)
        returns (
            address proposer,
            string memory title,
            string memory description,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 startTime,
            uint256 endTime,
            bool executed,
            bool cancelled
        )
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.cancelled
        );
    }

    function hasVoted(uint256 proposalId, address voter) external view
        proposalExists(proposalId)
        returns (bool)
    {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoterChoice(uint256 proposalId, address voter) external view
        proposalExists(proposalId)
        returns (uint256)
    {
        require(proposals[proposalId].hasVoted[voter], "DAOGovernance: voter has not voted");
        return proposals[proposalId].voterChoice[voter];
    }

    function getMemberInfo(address member) external view returns (
        bool isActive,
        uint256 votingPower,
        uint256 joinTime,
        uint256 proposalCount
    ) {
        Member memory memberInfo = members[member];
        return (
            memberInfo.isActive,
            memberInfo.votingPower,
            memberInfo.joinTime,
            memberProposalCount[member]
        );
    }

    function getAllMembers() external view returns (address[] memory) {
        return memberList;
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "DAOGovernance: new admin cannot be zero address");
        require(newAdmin != admin, "DAOGovernance: new admin is the same as current admin");

        address oldAdmin = admin;
        admin = newAdmin;

        emit AdminChanged(oldAdmin, newAdmin);
    }

    function updateVotingPeriod(uint256 newVotingPeriod) external onlyAdmin {
        require(newVotingPeriod > 0, "DAOGovernance: voting period must be greater than zero");

        uint256 oldPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;

        emit VotingPeriodUpdated(oldPeriod, newVotingPeriod);
    }

    function updateMinimumQuorum(uint256 newMinimumQuorum) external onlyAdmin {
        require(newMinimumQuorum > 0, "DAOGovernance: minimum quorum must be greater than zero");

        uint256 oldQuorum = minimumQuorum;
        minimumQuorum = newMinimumQuorum;

        emit QuorumUpdated(oldQuorum, newMinimumQuorum);
    }

    function updateProposalThreshold(uint256 newProposalThreshold) external onlyAdmin {
        uint256 oldThreshold = proposalThreshold;
        proposalThreshold = newProposalThreshold;

        emit ProposalThresholdUpdated(oldThreshold, newProposalThreshold);
    }

    function getContractInfo() external view returns (
        address governanceTokenAddress,
        address adminAddress,
        uint256 currentProposalCount,
        uint256 currentVotingPeriod,
        uint256 currentMinimumQuorum,
        uint256 currentProposalThreshold,
        uint256 currentTotalMembers,
        uint256 currentTotalVotingPower
    ) {
        return (
            address(governanceToken),
            admin,
            proposalCount,
            votingPeriod,
            minimumQuorum,
            proposalThreshold,
            totalMembers,
            totalVotingPower
        );
    }
}
