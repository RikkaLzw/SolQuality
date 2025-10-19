
pragma solidity ^0.8.19;


contract DAOGovernanceContract {



    IERC20 public immutable governanceToken;


    uint256 public proposalCount;


    uint256 public votingDelay;


    uint256 public votingPeriod;


    uint256 public proposalThreshold;


    uint256 public timelockDelay;




    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }




    struct Proposal {
        uint256 id;
        address proposer;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
        uint256 eta;
        mapping(address => Receipt) receipts;
    }


    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint256 votes;
    }




    mapping(uint256 => Proposal) public proposals;


    mapping(address => uint256) public latestProposalIds;




    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );


    event VoteCast(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        uint256 votes,
        string reason
    );


    event ProposalCanceled(uint256 id);


    event ProposalQueued(uint256 id, uint256 eta);


    event ProposalExecuted(uint256 id);




    modifier onlyGovernance() {
        require(msg.sender == address(this), "DAOGovernance: caller is not governance");
        _;
    }




    constructor(
        address _governanceToken,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _timelockDelay
    ) {
        require(_governanceToken != address(0), "DAOGovernance: invalid token address");
        require(_votingPeriod > 0, "DAOGovernance: invalid voting period");
        require(_timelockDelay >= 2 days, "DAOGovernance: timelock delay too short");

        governanceToken = IERC20(_governanceToken);
        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        timelockDelay = _timelockDelay;
    }




    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256) {
        require(
            getVotes(msg.sender, block.number - 1) >= proposalThreshold,
            "DAOGovernance: proposer votes below proposal threshold"
        );
        require(
            targets.length == values.length &&
            targets.length == signatures.length &&
            targets.length == calldatas.length,
            "DAOGovernance: proposal function information arity mismatch"
        );
        require(targets.length != 0, "DAOGovernance: must provide actions");
        require(targets.length <= 10, "DAOGovernance: too many actions");

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(latestProposalId);
            require(
                proposersLatestProposalState != ProposalState.Active,
                "DAOGovernance: one live proposal per proposer, found an already active proposal"
            );
            require(
                proposersLatestProposalState != ProposalState.Pending,
                "DAOGovernance: one live proposal per proposer, found an already pending proposal"
            );
        }

        uint256 startBlock = block.number + votingDelay;
        uint256 endBlock = startBlock + votingPeriod;

        proposalCount++;
        uint256 newProposalId = proposalCount;

        Proposal storage newProposal = proposals[newProposalId];
        newProposal.id = newProposalId;
        newProposal.proposer = msg.sender;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;
        newProposal.description = description;

        latestProposalIds[msg.sender] = newProposalId;

        emit ProposalCreated(
            newProposalId,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            startBlock,
            endBlock,
            description
        );

        return newProposalId;
    }


    function castVote(uint256 proposalId, uint8 support) external {
        emit VoteCast(msg.sender, proposalId, support, _castVote(msg.sender, proposalId, support), "");
    }


    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external {
        emit VoteCast(msg.sender, proposalId, support, _castVote(msg.sender, proposalId, support), reason);
    }


    function cancel(uint256 proposalId) external {
        require(state(proposalId) != ProposalState.Executed, "DAOGovernance: cannot cancel executed proposal");

        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer ||
            getVotes(proposal.proposer, block.number - 1) < proposalThreshold,
            "DAOGovernance: proposer above threshold"
        );

        proposal.canceled = true;

        emit ProposalCanceled(proposalId);
    }


    function queue(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "DAOGovernance: proposal can only be queued if it is succeeded"
        );

        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp + timelockDelay;
        proposal.eta = eta;

        emit ProposalQueued(proposalId, eta);
    }


    function execute(uint256 proposalId) external payable {
        require(
            state(proposalId) == ProposalState.Queued,
            "DAOGovernance: proposal can only be executed if it is queued"
        );

        Proposal storage proposal = proposals[proposalId];
        require(
            block.timestamp >= proposal.eta,
            "DAOGovernance: proposal hasn't finished timelock delay"
        );
        require(
            block.timestamp <= proposal.eta + 14 days,
            "DAOGovernance: transaction is stale"
        );

        proposal.executed = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _executeTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i]
            );
        }

        emit ProposalExecuted(proposalId);
    }




    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId && proposalId > 0, "DAOGovernance: invalid proposal id");

        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) {
            return ProposalState.Canceled;
        }

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        }

        if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        }

        if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < _quorum()) {
            return ProposalState.Defeated;
        }

        if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        }

        if (block.timestamp >= proposal.eta + 14 days) {
            return ProposalState.Expired;
        }

        return ProposalState.Queued;
    }


    function getReceipt(uint256 proposalId, address voter)
        external
        view
        returns (bool hasVoted, uint8 support, uint256 votes)
    {
        Receipt storage receipt = proposals[proposalId].receipts[voter];
        return (receipt.hasVoted, receipt.support, receipt.votes);
    }


    function getVotes(address account, uint256 blockNumber) public view returns (uint256) {
        return governanceToken.balanceOf(account);
    }




    function _castVote(address voter, uint256 proposalId, uint8 support) internal returns (uint256) {
        require(state(proposalId) == ProposalState.Active, "DAOGovernance: voting is closed");
        require(support <= 2, "DAOGovernance: invalid vote type");

        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(!receipt.hasVoted, "DAOGovernance: voter already voted");

        uint256 votes = getVotes(voter, proposal.startBlock);

        if (support == 0) {
            proposal.againstVotes += votes;
        } else if (support == 1) {
            proposal.forVotes += votes;
        } else {
            proposal.abstainVotes += votes;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        return votes;
    }


    function _executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data
    ) internal {
        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, ) = target.call{value: value}(callData);
        require(success, "DAOGovernance: transaction execution reverted");
    }


    function _quorum() internal view returns (uint256) {
        return (governanceToken.totalSupply() * 4) / 100;
    }




    function setVotingDelay(uint256 newVotingDelay) external onlyGovernance {
        votingDelay = newVotingDelay;
    }


    function setVotingPeriod(uint256 newVotingPeriod) external onlyGovernance {
        require(newVotingPeriod > 0, "DAOGovernance: invalid voting period");
        votingPeriod = newVotingPeriod;
    }


    function setProposalThreshold(uint256 newProposalThreshold) external onlyGovernance {
        proposalThreshold = newProposalThreshold;
    }




    receive() external payable {}
}


interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
