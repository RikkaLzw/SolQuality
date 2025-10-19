
pragma solidity ^0.8.0;


contract DAOGovernance {

    interface IERC20 {
        function balanceOf(address account) external view returns (uint256);
        function transfer(address to, uint256 amount) external returns (bool);
        function transferFrom(address from, address to, uint256 amount) external returns (bool);
    }


    enum ProposalState {
        Pending,
        Active,
        Succeeded,
        Defeated,
        Executed,
        Cancelled
    }


    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        address target;
        bytes data;
        uint256 value;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool cancelled;
        mapping(address => bool) hasVoted;
        mapping(address => uint8) votes;
    }


    IERC20 public governanceToken;
    address public admin;
    uint256 public proposalCount;
    uint256 public votingDelay = 1 days;
    uint256 public votingPeriod = 7 days;
    uint256 public proposalThreshold = 1000 * 10**18;
    uint256 public quorumVotes = 10000 * 10**18;
    uint256 public executionDelay = 2 days;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public latestProposalIds;


    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        string description,
        address target,
        uint256 value,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 weight,
        string reason
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event VotingDelayChanged(uint256 oldDelay, uint256 newDelay);
    event VotingPeriodChanged(uint256 oldPeriod, uint256 newPeriod);
    event ProposalThresholdChanged(uint256 oldThreshold, uint256 newThreshold);
    event QuorumVotesChanged(uint256 oldQuorum, uint256 newQuorum);


    modifier onlyAdmin() {
        require(msg.sender == admin, "DAOGovernance: caller is not the admin");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "DAOGovernance: invalid proposal ID");
        _;
    }

    constructor(address _governanceToken, address _admin) {
        require(_governanceToken != address(0), "DAOGovernance: governance token cannot be zero address");
        require(_admin != address(0), "DAOGovernance: admin cannot be zero address");

        governanceToken = IERC20(_governanceToken);
        admin = _admin;
    }


    function propose(
        string memory title,
        string memory description,
        address target,
        bytes memory data,
        uint256 value
    ) external returns (uint256) {
        require(bytes(title).length > 0, "DAOGovernance: proposal title cannot be empty");
        require(bytes(description).length > 0, "DAOGovernance: proposal description cannot be empty");
        require(target != address(0), "DAOGovernance: target cannot be zero address");

        uint256 proposerBalance = governanceToken.balanceOf(msg.sender);
        require(proposerBalance >= proposalThreshold, "DAOGovernance: proposer votes below proposal threshold");


        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposerLatestProposalState = state(latestProposalId);
            require(
                proposerLatestProposalState != ProposalState.Active &&
                proposerLatestProposalState != ProposalState.Pending,
                "DAOGovernance: one live proposal per proposer, found an already active proposal"
            );
        }

        proposalCount++;
        uint256 startTime = block.timestamp + votingDelay;
        uint256 endTime = startTime + votingPeriod;

        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.target = target;
        newProposal.data = data;
        newProposal.value = value;
        newProposal.startTime = startTime;
        newProposal.endTime = endTime;

        latestProposalIds[msg.sender] = proposalCount;

        emit ProposalCreated(
            proposalCount,
            msg.sender,
            title,
            description,
            target,
            value,
            startTime,
            endTime
        );

        return proposalCount;
    }


    function castVote(uint256 proposalId, uint8 support, string memory reason) external validProposal(proposalId) {
        require(support <= 2, "DAOGovernance: invalid vote type");

        ProposalState proposalState = state(proposalId);
        require(proposalState == ProposalState.Active, "DAOGovernance: voting is closed");

        Proposal storage proposal = proposals[proposalId];
        require(!proposal.hasVoted[msg.sender], "DAOGovernance: voter already voted");

        uint256 weight = governanceToken.balanceOf(msg.sender);
        require(weight > 0, "DAOGovernance: voter has no voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.votes[msg.sender] = support;

        if (support == 0) {
            proposal.againstVotes += weight;
        } else if (support == 1) {
            proposal.forVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }

        emit VoteCast(msg.sender, proposalId, support, weight, reason);
    }


    function execute(uint256 proposalId) external payable validProposal(proposalId) {
        ProposalState proposalState = state(proposalId);
        require(proposalState == ProposalState.Succeeded, "DAOGovernance: proposal can only be executed if it is succeeded");

        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "DAOGovernance: proposal already executed");
        require(block.timestamp >= proposal.endTime + executionDelay, "DAOGovernance: execution delay not met");

        proposal.executed = true;

        (bool success, ) = proposal.target.call{value: proposal.value}(proposal.data);
        require(success, "DAOGovernance: proposal execution reverted");

        emit ProposalExecuted(proposalId);
    }


    function cancel(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == admin || msg.sender == proposal.proposer,
            "DAOGovernance: only admin or proposer can cancel"
        );
        require(!proposal.executed, "DAOGovernance: cannot cancel executed proposal");
        require(!proposal.cancelled, "DAOGovernance: proposal already cancelled");

        proposal.cancelled = true;

        emit ProposalCancelled(proposalId);
    }


    function state(uint256 proposalId) public view validProposal(proposalId) returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.cancelled) {
            return ProposalState.Cancelled;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp < proposal.startTime) {
            return ProposalState.Pending;
        } else if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes) {
            return ProposalState.Defeated;
        } else {
            return ProposalState.Succeeded;
        }
    }


    function getProposal(uint256 proposalId) external view validProposal(proposalId) returns (
        uint256 id,
        address proposer,
        string memory title,
        string memory description,
        address target,
        bytes memory data,
        uint256 value,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        bool executed,
        bool cancelled
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.target,
            proposal.data,
            proposal.value,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.executed,
            proposal.cancelled
        );
    }


    function hasVoted(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }


    function getVote(uint256 proposalId, address voter) external view validProposal(proposalId) returns (uint8) {
        require(proposals[proposalId].hasVoted[voter], "DAOGovernance: voter has not voted");
        return proposals[proposalId].votes[voter];
    }


    function setVotingDelay(uint256 newVotingDelay) external onlyAdmin {
        require(newVotingDelay >= 1 hours && newVotingDelay <= 30 days, "DAOGovernance: invalid voting delay");
        uint256 oldDelay = votingDelay;
        votingDelay = newVotingDelay;
        emit VotingDelayChanged(oldDelay, newVotingDelay);
    }

    function setVotingPeriod(uint256 newVotingPeriod) external onlyAdmin {
        require(newVotingPeriod >= 1 days && newVotingPeriod <= 30 days, "DAOGovernance: invalid voting period");
        uint256 oldPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;
        emit VotingPeriodChanged(oldPeriod, newVotingPeriod);
    }

    function setProposalThreshold(uint256 newProposalThreshold) external onlyAdmin {
        require(newProposalThreshold > 0, "DAOGovernance: proposal threshold must be greater than 0");
        uint256 oldThreshold = proposalThreshold;
        proposalThreshold = newProposalThreshold;
        emit ProposalThresholdChanged(oldThreshold, newProposalThreshold);
    }

    function setQuorumVotes(uint256 newQuorumVotes) external onlyAdmin {
        require(newQuorumVotes > 0, "DAOGovernance: quorum votes must be greater than 0");
        uint256 oldQuorum = quorumVotes;
        quorumVotes = newQuorumVotes;
        emit QuorumVotesChanged(oldQuorum, newQuorumVotes);
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "DAOGovernance: new admin cannot be zero address");
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(oldAdmin, newAdmin);
    }


    function emergencyWithdraw() external onlyAdmin {
        payable(admin).transfer(address(this).balance);
    }


    receive() external payable {}
}
