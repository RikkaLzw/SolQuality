
pragma solidity ^0.8.19;


contract DAOGovernanceContract {

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


    enum VoteType {
        Against,
        For,
        Abstain
    }


    struct Proposal {
        uint256 proposalId;
        address proposer;
        string title;
        string description;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool cancelled;
        mapping(address => bool) hasVoted;
    }


    IERC20 public governanceToken;
    uint256 public proposalCount;
    uint256 public votingDelay;
    uint256 public votingPeriod;
    uint256 public proposalThreshold;
    uint256 public quorum;
    address public admin;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public latestProposalIds;


    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        string description,
        uint256 startBlock,
        uint256 endBlock
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


    modifier onlyAdmin() {
        require(msg.sender == admin, "DAOGovernance: caller is not admin");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "DAOGovernance: invalid proposal id");
        _;
    }


    constructor(
        address _governanceToken,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorum
    ) {
        require(_governanceToken != address(0), "DAOGovernance: invalid token address");
        require(_votingDelay > 0, "DAOGovernance: voting delay must be greater than 0");
        require(_votingPeriod > 0, "DAOGovernance: voting period must be greater than 0");
        require(_quorum > 0 && _quorum <= 100, "DAOGovernance: invalid quorum percentage");

        governanceToken = IERC20(_governanceToken);
        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorum = _quorum;
        admin = msg.sender;
    }


    function createProposal(
        string memory title,
        string memory description,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) external returns (uint256) {
        require(
            governanceToken.balanceOf(msg.sender) >= proposalThreshold,
            "DAOGovernance: proposer votes below proposal threshold"
        );
        require(
            targets.length == values.length && targets.length == calldatas.length,
            "DAOGovernance: proposal function information arity mismatch"
        );
        require(targets.length > 0, "DAOGovernance: empty proposal");

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposerLatestProposalState = getProposalState(latestProposalId);
            require(
                proposerLatestProposalState != ProposalState.Active,
                "DAOGovernance: one live proposal per proposer, found an already active proposal"
            );
            require(
                proposerLatestProposalState != ProposalState.Pending,
                "DAOGovernance: one live proposal per proposer, found an already pending proposal"
            );
        }

        proposalCount++;
        uint256 newProposalId = proposalCount;

        Proposal storage newProposal = proposals[newProposalId];
        newProposal.proposalId = newProposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = block.number + votingDelay;
        newProposal.endBlock = newProposal.startBlock + votingPeriod;

        latestProposalIds[msg.sender] = newProposalId;

        emit ProposalCreated(
            newProposalId,
            msg.sender,
            title,
            description,
            newProposal.startBlock,
            newProposal.endBlock
        );

        return newProposalId;
    }


    function castVote(
        uint256 proposalId,
        uint8 support,
        string memory reason
    ) external validProposal(proposalId) {
        require(support <= uint8(VoteType.Abstain), "DAOGovernance: invalid vote type");

        Proposal storage proposal = proposals[proposalId];
        ProposalState state = getProposalState(proposalId);
        require(state == ProposalState.Active, "DAOGovernance: voting is closed");
        require(!proposal.hasVoted[msg.sender], "DAOGovernance: voter already voted");

        uint256 weight = governanceToken.balanceOf(msg.sender);
        require(weight > 0, "DAOGovernance: voter has no voting power");

        proposal.hasVoted[msg.sender] = true;

        if (support == uint8(VoteType.Against)) {
            proposal.againstVotes += weight;
        } else if (support == uint8(VoteType.For)) {
            proposal.forVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }

        emit VoteCast(msg.sender, proposalId, support, weight, reason);
    }


    function executeProposal(uint256 proposalId) external payable validProposal(proposalId) {
        ProposalState state = getProposalState(proposalId);
        require(state == ProposalState.Succeeded, "DAOGovernance: proposal can only be executed if it is succeeded");

        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success, ) = proposal.targets[i].call{value: proposal.values[i]}(
                proposal.calldatas[i]
            );
            require(success, "DAOGovernance: transaction execution reverted");
        }

        emit ProposalExecuted(proposalId);
    }


    function cancelProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == admin || msg.sender == proposal.proposer,
            "DAOGovernance: only admin or proposer can cancel"
        );
        require(!proposal.executed, "DAOGovernance: cannot cancel executed proposal");

        proposal.cancelled = true;
        emit ProposalCancelled(proposalId);
    }


    function getProposalState(uint256 proposalId) public view validProposal(proposalId) returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.cancelled) {
            return ProposalState.Cancelled;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (_quorumReached(proposalId) && _voteSucceeded(proposalId)) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }


    function getProposal(uint256 proposalId) external view validProposal(proposalId) returns (
        address proposer,
        string memory title,
        string memory description,
        uint256 startBlock,
        uint256 endBlock,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        bool executed,
        bool cancelled
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.startBlock,
            proposal.endBlock,
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


    function updateGovernanceParams(
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorum
    ) external onlyAdmin {
        require(_votingDelay > 0, "DAOGovernance: voting delay must be greater than 0");
        require(_votingPeriod > 0, "DAOGovernance: voting period must be greater than 0");
        require(_quorum > 0 && _quorum <= 100, "DAOGovernance: invalid quorum percentage");

        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorum = _quorum;
    }


    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "DAOGovernance: new admin is the zero address");
        admin = newAdmin;
    }


    function _quorumReached(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 totalSupply = governanceToken.balanceOf(address(this)) +
                             governanceToken.balanceOf(address(governanceToken));
        return totalVotes >= (totalSupply * quorum) / 100;
    }


    function _voteSucceeded(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return proposal.forVotes > proposal.againstVotes;
    }


    receive() external payable {}
}
