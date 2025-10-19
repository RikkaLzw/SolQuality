
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {

    uint256 public constant MAX_PROJECTS = 100;
    uint256 public projectCount = 0;
    uint256 public platformFeePercent = 5;

    address public owner;


    mapping(string => bool) public projectIds;

    struct Project {
        string projectId;
        address creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        uint256 status;
        bytes extraData;
        uint256 isActive;
    }

    mapping(string => Project) public projects;
    mapping(string => mapping(address => uint256)) public contributions;
    mapping(string => address[]) public contributors;

    event ProjectCreated(string projectId, address creator, uint256 goalAmount, uint256 deadline);
    event ContributionMade(string projectId, address contributor, uint256 amount);
    event ProjectFunded(string projectId, uint256 totalRaised);
    event RefundIssued(string projectId, address contributor, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier projectExists(string memory _projectId) {
        require(projectIds[_projectId], "Project does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createProject(
        string memory _projectId,
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays,
        bytes memory _extraData
    ) external {
        require(!projectIds[_projectId], "Project ID already exists");
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");


        uint256 convertedProjectCount = uint256(projectCount);
        require(convertedProjectCount < uint256(MAX_PROJECTS), "Maximum projects reached");

        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        projects[_projectId] = Project({
            projectId: _projectId,
            creator: msg.sender,
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            deadline: deadline,
            status: 0,
            extraData: _extraData,
            isActive: 1
        });

        projectIds[_projectId] = true;
        projectCount = uint256(projectCount + 1);

        emit ProjectCreated(_projectId, msg.sender, _goalAmount, deadline);
    }

    function contribute(string memory _projectId) external payable projectExists(_projectId) {
        Project storage project = projects[_projectId];
        require(uint256(project.isActive) == 1, "Project is not active");
        require(block.timestamp < project.deadline, "Project deadline has passed");
        require(msg.value > 0, "Contribution must be greater than 0");

        if (contributions[_projectId][msg.sender] == 0) {
            contributors[_projectId].push(msg.sender);
        }

        contributions[_projectId][msg.sender] += msg.value;
        project.raisedAmount += msg.value;

        emit ContributionMade(_projectId, msg.sender, msg.value);


        if (project.raisedAmount >= project.goalAmount) {
            project.status = uint256(1);
            emit ProjectFunded(_projectId, project.raisedAmount);
        }
    }

    function finalizeProject(string memory _projectId) external projectExists(_projectId) {
        Project storage project = projects[_projectId];
        require(msg.sender == project.creator, "Only project creator can finalize");
        require(block.timestamp >= project.deadline, "Project deadline not reached");
        require(uint256(project.isActive) == 1, "Project is not active");

        project.isActive = uint256(0);

        if (project.raisedAmount >= project.goalAmount) {
            project.status = uint256(1);


            uint256 platformFee = (project.raisedAmount * uint256(platformFeePercent)) / 100;
            uint256 creatorAmount = project.raisedAmount - platformFee;


            payable(project.creator).transfer(creatorAmount);


            if (platformFee > 0) {
                payable(owner).transfer(platformFee);
            }
        } else {
            project.status = uint256(2);
        }
    }

    function claimRefund(string memory _projectId) external projectExists(_projectId) {
        Project storage project = projects[_projectId];
        require(uint256(project.status) == 2, "Project did not fail");

        uint256 contributionAmount = contributions[_projectId][msg.sender];
        require(contributionAmount > 0, "No contribution found");

        contributions[_projectId][msg.sender] = 0;
        payable(msg.sender).transfer(contributionAmount);

        emit RefundIssued(_projectId, msg.sender, contributionAmount);
    }

    function getProject(string memory _projectId) external view returns (
        string memory projectId,
        address creator,
        string memory title,
        string memory description,
        uint256 goalAmount,
        uint256 raisedAmount,
        uint256 deadline,
        uint256 status,
        bytes memory extraData,
        uint256 isActive
    ) {
        Project storage project = projects[_projectId];
        return (
            project.projectId,
            project.creator,
            project.title,
            project.description,
            project.goalAmount,
            project.raisedAmount,
            project.deadline,
            project.status,
            project.extraData,
            project.isActive
        );
    }

    function getContribution(string memory _projectId, address _contributor) external view returns (uint256) {
        return contributions[_projectId][_contributor];
    }

    function getContributorsCount(string memory _projectId) external view returns (uint256) {
        return contributors[_projectId].length;
    }

    function updatePlatformFee(uint256 _newFeePercent) external onlyOwner {
        require(uint256(_newFeePercent) <= 10, "Fee cannot exceed 10%");
        platformFeePercent = uint256(_newFeePercent);
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
