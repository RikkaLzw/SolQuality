
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {

    uint256 public constant MAX_PROJECTS = 100;
    uint256 public projectCount = 0;
    uint256 public platformFeePercent = 5;


    struct Project {
        string projectId;
        address creator;
        string title;
        string description;
        uint256 targetAmount;
        uint256 raisedAmount;
        uint256 deadline;
        uint256 isActive;
        uint256 isCompleted;
        bytes metadata;
    }

    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(address => uint256[]) public userProjects;

    address public owner;
    uint256 public totalPlatformFees;

    event ProjectCreated(uint256 indexed projectId, address indexed creator, uint256 targetAmount);
    event ContributionMade(uint256 indexed projectId, address indexed contributor, uint256 amount);
    event ProjectCompleted(uint256 indexed projectId, uint256 totalRaised);
    event FundsWithdrawn(uint256 indexed projectId, address indexed creator, uint256 amount);
    event RefundIssued(uint256 indexed projectId, address indexed contributor, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validProject(uint256 _projectId) {
        require(_projectId < projectCount, "Project does not exist");
        require(projects[_projectId].isActive == 1, "Project is not active");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createProject(
        string memory _projectId,
        string memory _title,
        string memory _description,
        uint256 _targetAmount,
        uint256 _durationInDays,
        bytes memory _metadata
    ) external {
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(projectCount < MAX_PROJECTS, "Maximum projects limit reached");


        uint256 deadline = block.timestamp + (uint256(_durationInDays) * 1 days);

        projects[projectCount] = Project({
            projectId: _projectId,
            creator: msg.sender,
            title: _title,
            description: _description,
            targetAmount: _targetAmount,
            raisedAmount: 0,
            deadline: deadline,
            isActive: uint256(1),
            isCompleted: uint256(0),
            metadata: _metadata
        });

        userProjects[msg.sender].push(projectCount);

        emit ProjectCreated(projectCount, msg.sender, _targetAmount);


        projectCount = uint256(projectCount + 1);
    }

    function contribute(uint256 _projectId) external payable validProject(_projectId) {
        require(msg.value > 0, "Contribution must be greater than 0");
        require(block.timestamp < projects[_projectId].deadline, "Project deadline has passed");
        require(projects[_projectId].isCompleted == 0, "Project already completed");

        contributions[_projectId][msg.sender] += msg.value;
        projects[_projectId].raisedAmount += msg.value;

        emit ContributionMade(_projectId, msg.sender, msg.value);


        if (projects[_projectId].raisedAmount >= projects[_projectId].targetAmount) {

            projects[_projectId].isCompleted = uint256(1);
            emit ProjectCompleted(_projectId, projects[_projectId].raisedAmount);
        }
    }

    function withdrawFunds(uint256 _projectId) external {
        require(msg.sender == projects[_projectId].creator, "Only project creator can withdraw");
        require(projects[_projectId].isCompleted == 1, "Project not completed");
        require(projects[_projectId].raisedAmount > 0, "No funds to withdraw");

        uint256 totalRaised = projects[_projectId].raisedAmount;

        uint256 platformFee = (uint256(totalRaised) * platformFeePercent) / 100;
        uint256 creatorAmount = totalRaised - platformFee;

        projects[_projectId].raisedAmount = 0;
        projects[_projectId].isActive = uint256(0);

        totalPlatformFees += platformFee;

        payable(msg.sender).transfer(creatorAmount);

        emit FundsWithdrawn(_projectId, msg.sender, creatorAmount);
    }

    function requestRefund(uint256 _projectId) external {
        require(block.timestamp > projects[_projectId].deadline, "Project deadline not reached");
        require(projects[_projectId].isCompleted == 0, "Project was completed");
        require(contributions[_projectId][msg.sender] > 0, "No contribution found");

        uint256 contributionAmount = contributions[_projectId][msg.sender];
        contributions[_projectId][msg.sender] = 0;
        projects[_projectId].raisedAmount -= contributionAmount;

        payable(msg.sender).transfer(contributionAmount);

        emit RefundIssued(_projectId, msg.sender, contributionAmount);
    }

    function withdrawPlatformFees() external onlyOwner {
        require(totalPlatformFees > 0, "No platform fees to withdraw");

        uint256 amount = totalPlatformFees;
        totalPlatformFees = 0;

        payable(owner).transfer(amount);
    }

    function getProject(uint256 _projectId) external view returns (
        string memory projectId,
        address creator,
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 raisedAmount,
        uint256 deadline,
        uint256 isActive,
        uint256 isCompleted,
        bytes memory metadata
    ) {
        require(_projectId < projectCount, "Project does not exist");
        Project memory project = projects[_projectId];
        return (
            project.projectId,
            project.creator,
            project.title,
            project.description,
            project.targetAmount,
            project.raisedAmount,
            project.deadline,
            project.isActive,
            project.isCompleted,
            project.metadata
        );
    }

    function getUserProjects(address _user) external view returns (uint256[] memory) {
        return userProjects[_user];
    }

    function getContribution(uint256 _projectId, address _contributor) external view returns (uint256) {
        return contributions[_projectId][_contributor];
    }


    function updatePlatformFee(uint256 _newFeePercent) external onlyOwner {
        require(_newFeePercent <= 10, "Platform fee cannot exceed 10%");
        platformFeePercent = _newFeePercent;
    }


    function isProjectActive(uint256 _projectId) external view returns (uint256) {
        require(_projectId < projectCount, "Project does not exist");
        return projects[_projectId].isActive;
    }

    function isProjectCompleted(uint256 _projectId) external view returns (uint256) {
        require(_projectId < projectCount, "Project does not exist");
        return projects[_projectId].isCompleted;
    }
}
