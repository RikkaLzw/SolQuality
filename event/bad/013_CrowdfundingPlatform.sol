
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    enum ProjectStatus { Active, Successful, Failed, Withdrawn }

    struct Project {
        address creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 currentAmount;
        uint256 deadline;
        ProjectStatus status;
        bool fundsWithdrawn;
    }

    struct Contribution {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => Contribution)) public contributions;
    mapping(uint256 => address[]) public projectContributors;

    uint256 public nextProjectId;
    uint256 public platformFeeRate = 250;
    address public owner;


    event ProjectCreated(uint256 projectId, address creator, uint256 goalAmount, uint256 deadline);
    event ContributionMade(uint256 projectId, address contributor, uint256 amount);
    event ProjectStatusChanged(uint256 projectId, ProjectStatus newStatus);
    event FundsWithdrawn(uint256 projectId, uint256 amount);
    event RefundIssued(uint256 projectId, address contributor, uint256 amount);

    error InvalidAmount();
    error NotFound();
    error AccessDenied();
    error InvalidStatus();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier validProject(uint256 _projectId) {
        require(_projectId < nextProjectId);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createProject(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(_goalAmount > 0);
        require(_durationInDays > 0);
        require(bytes(_title).length > 0);

        uint256 projectId = nextProjectId++;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        projects[projectId] = Project({
            creator: msg.sender,
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            currentAmount: 0,
            deadline: deadline,
            status: ProjectStatus.Active,
            fundsWithdrawn: false
        });

        emit ProjectCreated(projectId, msg.sender, _goalAmount, deadline);
        return projectId;
    }

    function contribute(uint256 _projectId) external payable validProject(_projectId) {
        require(msg.value > 0);

        Project storage project = projects[_projectId];
        require(project.status == ProjectStatus.Active);
        require(block.timestamp <= project.deadline);

        if (contributions[_projectId][msg.sender].amount == 0) {
            projectContributors[_projectId].push(msg.sender);
        }

        contributions[_projectId][msg.sender].amount += msg.value;
        contributions[_projectId][msg.sender].timestamp = block.timestamp;
        project.currentAmount += msg.value;


        if (project.currentAmount >= project.goalAmount) {
            project.status = ProjectStatus.Successful;
        }

        emit ContributionMade(_projectId, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _projectId) external validProject(_projectId) {
        Project storage project = projects[_projectId];
        require(msg.sender == project.creator);
        require(project.status == ProjectStatus.Successful);
        require(!project.fundsWithdrawn);

        uint256 platformFee = (project.currentAmount * platformFeeRate) / 10000;
        uint256 creatorAmount = project.currentAmount - platformFee;

        project.fundsWithdrawn = true;

        project.status = ProjectStatus.Withdrawn;

        payable(owner).transfer(platformFee);
        payable(project.creator).transfer(creatorAmount);

        emit FundsWithdrawn(_projectId, creatorAmount);
    }

    function refund(uint256 _projectId) external validProject(_projectId) {
        Project storage project = projects[_projectId];
        require(block.timestamp > project.deadline);
        require(project.status == ProjectStatus.Active);
        require(contributions[_projectId][msg.sender].amount > 0);

        uint256 refundAmount = contributions[_projectId][msg.sender].amount;
        contributions[_projectId][msg.sender].amount = 0;
        project.currentAmount -= refundAmount;


        if (project.currentAmount == 0) {
            project.status = ProjectStatus.Failed;
        }

        payable(msg.sender).transfer(refundAmount);
        emit RefundIssued(_projectId, msg.sender, refundAmount);
    }

    function updateProjectStatus(uint256 _projectId) external validProject(_projectId) {
        Project storage project = projects[_projectId];
        require(msg.sender == project.creator || msg.sender == owner);

        if (block.timestamp > project.deadline && project.status == ProjectStatus.Active) {
            if (project.currentAmount >= project.goalAmount) {
                project.status = ProjectStatus.Successful;
            } else {
                project.status = ProjectStatus.Failed;
            }
            emit ProjectStatusChanged(_projectId, project.status);
        }
    }

    function getProject(uint256 _projectId) external view validProject(_projectId) returns (
        address creator,
        string memory title,
        string memory description,
        uint256 goalAmount,
        uint256 currentAmount,
        uint256 deadline,
        ProjectStatus status,
        bool fundsWithdrawn
    ) {
        Project storage project = projects[_projectId];
        return (
            project.creator,
            project.title,
            project.description,
            project.goalAmount,
            project.currentAmount,
            project.deadline,
            project.status,
            project.fundsWithdrawn
        );
    }

    function getContribution(uint256 _projectId, address _contributor) external view returns (uint256, uint256) {
        Contribution storage contribution = contributions[_projectId][_contributor];
        return (contribution.amount, contribution.timestamp);
    }

    function getProjectContributors(uint256 _projectId) external view validProject(_projectId) returns (address[] memory) {
        return projectContributors[_projectId];
    }

    function updatePlatformFeeRate(uint256 _newRate) external onlyOwner {
        require(_newRate <= 1000);
        platformFeeRate = _newRate;
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
