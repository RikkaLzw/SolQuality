
pragma solidity ^0.8.0;


contract CrowdfundingPlatform {


    enum ProjectStatus {
        Active,
        Successful,
        Failed,
        Withdrawn
    }


    struct Project {
        uint256 projectId;
        address payable creator;
        string title;
        string description;
        uint256 targetAmount;
        uint256 currentAmount;
        uint256 deadline;
        ProjectStatus status;
        bool fundsWithdrawn;
    }


    struct Investment {
        address investor;
        uint256 amount;
        uint256 timestamp;
    }


    uint256 private nextProjectId;
    mapping(uint256 => Project) public projects;
    mapping(uint256 => Investment[]) public projectInvestments;
    mapping(uint256 => mapping(address => uint256)) public investorContributions;

    address public platformOwner;
    uint256 public platformFeeRate;
    uint256 public minimumProjectDuration;
    uint256 public maximumProjectDuration;


    event ProjectCreated(
        uint256 indexed projectId,
        address indexed creator,
        string title,
        uint256 targetAmount,
        uint256 deadline
    );

    event InvestmentMade(
        uint256 indexed projectId,
        address indexed investor,
        uint256 amount,
        uint256 newTotalAmount
    );

    event ProjectSuccessful(
        uint256 indexed projectId,
        uint256 finalAmount
    );

    event ProjectFailed(
        uint256 indexed projectId,
        uint256 finalAmount
    );

    event FundsWithdrawn(
        uint256 indexed projectId,
        address indexed creator,
        uint256 amount,
        uint256 platformFee
    );

    event RefundIssued(
        uint256 indexed projectId,
        address indexed investor,
        uint256 amount
    );

    event PlatformFeeUpdated(
        uint256 oldFeeRate,
        uint256 newFeeRate
    );


    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this function");
        _;
    }

    modifier projectExists(uint256 _projectId) {
        require(_projectId < nextProjectId, "Project does not exist");
        _;
    }

    modifier onlyProjectCreator(uint256 _projectId) {
        require(msg.sender == projects[_projectId].creator, "Only project creator can call this function");
        _;
    }


    constructor(uint256 _platformFeeRate) {
        require(_platformFeeRate <= 1000, "Platform fee rate cannot exceed 10%");

        platformOwner = msg.sender;
        platformFeeRate = _platformFeeRate;
        minimumProjectDuration = 7 days;
        maximumProjectDuration = 365 days;
        nextProjectId = 0;
    }


    function createProject(
        string memory _title,
        string memory _description,
        uint256 _targetAmount,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Project title cannot be empty");
        require(bytes(_description).length > 0, "Project description cannot be empty");
        require(_targetAmount > 0, "Target amount must be greater than zero");

        uint256 durationInSeconds = _durationInDays * 1 days;
        require(durationInSeconds >= minimumProjectDuration, "Project duration too short");
        require(durationInSeconds <= maximumProjectDuration, "Project duration too long");

        uint256 projectId = nextProjectId;
        uint256 deadline = block.timestamp + durationInSeconds;

        projects[projectId] = Project({
            projectId: projectId,
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            targetAmount: _targetAmount,
            currentAmount: 0,
            deadline: deadline,
            status: ProjectStatus.Active,
            fundsWithdrawn: false
        });

        nextProjectId++;

        emit ProjectCreated(projectId, msg.sender, _title, _targetAmount, deadline);

        return projectId;
    }


    function investInProject(uint256 _projectId) external payable projectExists(_projectId) {
        require(msg.value > 0, "Investment amount must be greater than zero");

        Project storage project = projects[_projectId];
        require(project.status == ProjectStatus.Active, "Project is not active");
        require(block.timestamp < project.deadline, "Project deadline has passed");
        require(msg.sender != project.creator, "Project creator cannot invest in own project");


        project.currentAmount += msg.value;
        investorContributions[_projectId][msg.sender] += msg.value;

        projectInvestments[_projectId].push(Investment({
            investor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));


        if (project.currentAmount >= project.targetAmount) {
            project.status = ProjectStatus.Successful;
            emit ProjectSuccessful(_projectId, project.currentAmount);
        }

        emit InvestmentMade(_projectId, msg.sender, msg.value, project.currentAmount);
    }


    function updateProjectStatus(uint256 _projectId) external projectExists(_projectId) {
        Project storage project = projects[_projectId];

        if (project.status == ProjectStatus.Active && block.timestamp >= project.deadline) {
            if (project.currentAmount >= project.targetAmount) {
                project.status = ProjectStatus.Successful;
                emit ProjectSuccessful(_projectId, project.currentAmount);
            } else {
                project.status = ProjectStatus.Failed;
                emit ProjectFailed(_projectId, project.currentAmount);
            }
        }
    }


    function withdrawFunds(uint256 _projectId) external projectExists(_projectId) onlyProjectCreator(_projectId) {
        Project storage project = projects[_projectId];


        if (project.status == ProjectStatus.Active && block.timestamp >= project.deadline) {
            if (project.currentAmount >= project.targetAmount) {
                project.status = ProjectStatus.Successful;
            } else {
                project.status = ProjectStatus.Failed;
            }
        }

        require(project.status == ProjectStatus.Successful, "Project must be successful to withdraw funds");
        require(!project.fundsWithdrawn, "Funds have already been withdrawn");

        project.fundsWithdrawn = true;
        project.status = ProjectStatus.Withdrawn;


        uint256 platformFee = (project.currentAmount * platformFeeRate) / 10000;
        uint256 creatorAmount = project.currentAmount - platformFee;


        project.creator.transfer(creatorAmount);


        if (platformFee > 0) {
            payable(platformOwner).transfer(platformFee);
        }

        emit FundsWithdrawn(_projectId, project.creator, creatorAmount, platformFee);
    }


    function requestRefund(uint256 _projectId) external projectExists(_projectId) {
        Project storage project = projects[_projectId];


        if (project.status == ProjectStatus.Active && block.timestamp >= project.deadline) {
            if (project.currentAmount >= project.targetAmount) {
                project.status = ProjectStatus.Successful;
            } else {
                project.status = ProjectStatus.Failed;
            }
        }

        require(project.status == ProjectStatus.Failed, "Refunds only available for failed projects");

        uint256 investmentAmount = investorContributions[_projectId][msg.sender];
        require(investmentAmount > 0, "No investment found for this investor");


        investorContributions[_projectId][msg.sender] = 0;


        payable(msg.sender).transfer(investmentAmount);

        emit RefundIssued(_projectId, msg.sender, investmentAmount);
    }


    function getProject(uint256 _projectId) external view projectExists(_projectId) returns (Project memory) {
        return projects[_projectId];
    }


    function getInvestmentCount(uint256 _projectId) external view projectExists(_projectId) returns (uint256) {
        return projectInvestments[_projectId].length;
    }


    function getInvestment(uint256 _projectId, uint256 _index) external view projectExists(_projectId) returns (Investment memory) {
        require(_index < projectInvestments[_projectId].length, "Investment index out of bounds");
        return projectInvestments[_projectId][_index];
    }


    function getInvestorContribution(uint256 _projectId, address _investor) external view projectExists(_projectId) returns (uint256) {
        return investorContributions[_projectId][_investor];
    }


    function getTotalProjectCount() external view returns (uint256) {
        return nextProjectId;
    }


    function updatePlatformFeeRate(uint256 _newFeeRate) external onlyPlatformOwner {
        require(_newFeeRate <= 1000, "Platform fee rate cannot exceed 10%");

        uint256 oldFeeRate = platformFeeRate;
        platformFeeRate = _newFeeRate;

        emit PlatformFeeUpdated(oldFeeRate, _newFeeRate);
    }


    function updateProjectDurationLimits(uint256 _minDuration, uint256 _maxDuration) external onlyPlatformOwner {
        require(_minDuration > 0, "Minimum duration must be greater than zero");
        require(_maxDuration > _minDuration, "Maximum duration must be greater than minimum duration");

        minimumProjectDuration = _minDuration;
        maximumProjectDuration = _maxDuration;
    }


    function transferPlatformOwnership(address _newOwner) external onlyPlatformOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != platformOwner, "New owner must be different from current owner");

        platformOwner = _newOwner;
    }


    function emergencyWithdraw() external onlyPlatformOwner {
        payable(platformOwner).transfer(address(this).balance);
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
