
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {

    uint256 public constant MIN_CONTRIBUTION = 1;
    uint256 public constant MAX_PROJECTS = 100;
    uint256 public projectCount;


    mapping(string => uint256) public projectIds;


    mapping(uint256 => bytes) public projectHashes;

    struct Project {
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;

        uint256 isActive;
        uint256 isCompleted;
    }

    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => address[]) public contributors;

    event ProjectCreated(uint256 indexed projectId, address indexed creator, string title, uint256 goalAmount);
    event ContributionMade(uint256 indexed projectId, address indexed contributor, uint256 amount);
    event ProjectCompleted(uint256 indexed projectId, uint256 totalRaised);
    event RefundIssued(uint256 indexed projectId, address indexed contributor, uint256 amount);

    modifier onlyProjectCreator(uint256 _projectId) {
        require(projects[_projectId].creator == msg.sender, "Only project creator can call this");
        _;
    }

    modifier projectExists(uint256 _projectId) {
        require(_projectId > 0 && _projectId <= projectCount, "Project does not exist");
        _;
    }

    function createProject(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays,
        string memory _projectIdentifier,
        bytes memory _projectHash
    ) external {
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");


        projectCount = uint256(projectCount + uint256(1));

        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        projects[projectCount] = Project({
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            deadline: deadline,
            isActive: uint256(1),
            isCompleted: uint256(0)
        });


        projectIds[_projectIdentifier] = projectCount;


        projectHashes[projectCount] = _projectHash;

        emit ProjectCreated(projectCount, msg.sender, _title, _goalAmount);
    }

    function contribute(uint256 _projectId) external payable projectExists(_projectId) {
        Project storage project = projects[_projectId];

        require(project.isActive == uint256(1), "Project is not active");
        require(block.timestamp < project.deadline, "Project deadline has passed");
        require(msg.value >= MIN_CONTRIBUTION, "Contribution too small");

        if (contributions[_projectId][msg.sender] == 0) {
            contributors[_projectId].push(msg.sender);
        }

        contributions[_projectId][msg.sender] += msg.value;
        project.raisedAmount += msg.value;

        emit ContributionMade(_projectId, msg.sender, msg.value);


        if (project.raisedAmount >= project.goalAmount) {
            project.isCompleted = uint256(1);
            project.isActive = uint256(0);
            emit ProjectCompleted(_projectId, project.raisedAmount);
        }
    }

    function withdrawFunds(uint256 _projectId) external projectExists(_projectId) onlyProjectCreator(_projectId) {
        Project storage project = projects[_projectId];

        require(project.isCompleted == uint256(1), "Project not completed");
        require(project.raisedAmount > 0, "No funds to withdraw");

        uint256 amount = project.raisedAmount;
        project.raisedAmount = 0;

        project.creator.transfer(amount);
    }

    function requestRefund(uint256 _projectId) external projectExists(_projectId) {
        Project storage project = projects[_projectId];

        require(block.timestamp > project.deadline, "Project deadline not reached");
        require(project.raisedAmount < project.goalAmount, "Project was successful");
        require(contributions[_projectId][msg.sender] > 0, "No contribution found");

        uint256 contributionAmount = contributions[_projectId][msg.sender];
        contributions[_projectId][msg.sender] = 0;

        payable(msg.sender).transfer(contributionAmount);

        emit RefundIssued(_projectId, msg.sender, contributionAmount);
    }

    function getProjectDetails(uint256 _projectId) external view projectExists(_projectId) returns (
        address creator,
        string memory title,
        string memory description,
        uint256 goalAmount,
        uint256 raisedAmount,
        uint256 deadline,
        bool isActive,
        bool isCompleted
    ) {
        Project storage project = projects[_projectId];

        return (
            project.creator,
            project.title,
            project.description,
            project.goalAmount,
            project.raisedAmount,
            project.deadline,

            bool(project.isActive == uint256(1)),
            bool(project.isCompleted == uint256(1))
        );
    }

    function getContributors(uint256 _projectId) external view projectExists(_projectId) returns (address[] memory) {
        return contributors[_projectId];
    }

    function getContribution(uint256 _projectId, address _contributor) external view projectExists(_projectId) returns (uint256) {
        return contributions[_projectId][_contributor];
    }

    function getProjectByIdentifier(string memory _identifier) external view returns (uint256) {
        return projectIds[_identifier];
    }

    function getProjectHash(uint256 _projectId) external view projectExists(_projectId) returns (bytes memory) {
        return projectHashes[_projectId];
    }


    function getProjectStatus(uint256 _projectId) external view projectExists(_projectId) returns (uint256, uint256) {
        Project storage project = projects[_projectId];
        return (project.isActive, project.isCompleted);
    }
}
