
pragma solidity ^0.8.19;


contract CrowdfundingPlatform {


    enum ProjectStatus {
        Active,
        Successful,
        Failed,
        Cancelled
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
    uint256 public platformFeeRate;
    address payable public platformOwner;

    mapping(uint256 => Project) public projects;
    mapping(uint256 => Investment[]) public projectInvestments;
    mapping(uint256 => mapping(address => uint256)) public investorAmounts;
    mapping(address => uint256[]) public creatorProjects;
    mapping(address => uint256[]) public investorProjects;


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
        uint256 newTotal
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

    event ProjectCancelled(
        uint256 indexed projectId,
        address indexed creator
    );


    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this function");
        _;
    }

    modifier onlyProjectCreator(uint256 _projectId) {
        require(projects[_projectId].creator == msg.sender, "Only project creator can call this function");
        _;
    }

    modifier projectExists(uint256 _projectId) {
        require(_projectId < nextProjectId, "Project does not exist");
        _;
    }

    modifier validProjectStatus(uint256 _projectId, ProjectStatus _expectedStatus) {
        require(projects[_projectId].status == _expectedStatus, "Invalid project status");
        _;
    }


    constructor(uint256 _platformFeeRate) {
        require(_platformFeeRate <= 1000, "Platform fee rate cannot exceed 10%");
        platformOwner = payable(msg.sender);
        platformFeeRate = _platformFeeRate;
        nextProjectId = 0;
    }


    function createProject(
        string memory _title,
        string memory _description,
        uint256 _targetAmount,
        uint256 _durationDays
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(_durationDays > 0 && _durationDays <= 365, "Duration must be between 1 and 365 days");

        uint256 projectId = nextProjectId;
        uint256 deadline = block.timestamp + (_durationDays * 1 days);

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

        creatorProjects[msg.sender].push(projectId);
        nextProjectId++;

        emit ProjectCreated(projectId, msg.sender, _title, _targetAmount, deadline);

        return projectId;
    }


    function investInProject(uint256 _projectId)
        external
        payable
        projectExists(_projectId)
        validProjectStatus(_projectId, ProjectStatus.Active)
    {
        require(msg.value > 0, "Investment amount must be greater than 0");
        require(block.timestamp <= projects[_projectId].deadline, "Project deadline has passed");
        require(msg.sender != projects[_projectId].creator, "Creator cannot invest in own project");

        Project storage project = projects[_projectId];


        if (investorAmounts[_projectId][msg.sender] == 0) {
            investorProjects[msg.sender].push(_projectId);
        }

        investorAmounts[_projectId][msg.sender] += msg.value;
        project.currentAmount += msg.value;

        projectInvestments[_projectId].push(Investment({
            investor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));

        emit InvestmentMade(_projectId, msg.sender, msg.value, project.currentAmount);


        if (project.currentAmount >= project.targetAmount) {
            project.status = ProjectStatus.Successful;
            emit ProjectSuccessful(_projectId, project.currentAmount);
        }
    }


    function withdrawFunds(uint256 _projectId)
        external
        projectExists(_projectId)
        onlyProjectCreator(_projectId)
        validProjectStatus(_projectId, ProjectStatus.Successful)
    {
        Project storage project = projects[_projectId];
        require(!project.fundsWithdrawn, "Funds already withdrawn");
        require(project.currentAmount > 0, "No funds to withdraw");

        project.fundsWithdrawn = true;

        uint256 platformFee = (project.currentAmount * platformFeeRate) / 10000;
        uint256 creatorAmount = project.currentAmount - platformFee;


        project.creator.transfer(creatorAmount);


        if (platformFee > 0) {
            platformOwner.transfer(platformFee);
        }

        emit FundsWithdrawn(_projectId, project.creator, creatorAmount, platformFee);
    }


    function requestRefund(uint256 _projectId)
        external
        projectExists(_projectId)
    {
        Project storage project = projects[_projectId];


        if (project.status == ProjectStatus.Active && block.timestamp > project.deadline) {
            if (project.currentAmount >= project.targetAmount) {
                project.status = ProjectStatus.Successful;
            } else {
                project.status = ProjectStatus.Failed;
                emit ProjectFailed(_projectId, project.currentAmount);
            }
        }

        require(
            project.status == ProjectStatus.Failed || project.status == ProjectStatus.Cancelled,
            "Refunds only available for failed or cancelled projects"
        );

        uint256 investmentAmount = investorAmounts[_projectId][msg.sender];
        require(investmentAmount > 0, "No investment found for this investor");

        investorAmounts[_projectId][msg.sender] = 0;
        project.currentAmount -= investmentAmount;

        payable(msg.sender).transfer(investmentAmount);

        emit RefundIssued(_projectId, msg.sender, investmentAmount);
    }


    function cancelProject(uint256 _projectId)
        external
        projectExists(_projectId)
        onlyProjectCreator(_projectId)
        validProjectStatus(_projectId, ProjectStatus.Active)
    {
        projects[_projectId].status = ProjectStatus.Cancelled;
        emit ProjectCancelled(_projectId, msg.sender);
    }


    function updatePlatformFeeRate(uint256 _newFeeRate)
        external
        onlyPlatformOwner
    {
        require(_newFeeRate <= 1000, "Platform fee rate cannot exceed 10%");
        platformFeeRate = _newFeeRate;
    }


    function getProjectDetails(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (
            uint256 projectId,
            address creator,
            string memory title,
            string memory description,
            uint256 targetAmount,
            uint256 currentAmount,
            uint256 deadline,
            ProjectStatus status,
            bool fundsWithdrawn
        )
    {
        Project storage project = projects[_projectId];
        return (
            project.projectId,
            project.creator,
            project.title,
            project.description,
            project.targetAmount,
            project.currentAmount,
            project.deadline,
            project.status,
            project.fundsWithdrawn
        );
    }


    function getInvestmentCount(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (uint256)
    {
        return projectInvestments[_projectId].length;
    }


    function getInvestmentRecord(uint256 _projectId, uint256 _index)
        external
        view
        projectExists(_projectId)
        returns (address investor, uint256 amount, uint256 timestamp)
    {
        require(_index < projectInvestments[_projectId].length, "Investment record does not exist");
        Investment storage investment = projectInvestments[_projectId][_index];
        return (investment.investor, investment.amount, investment.timestamp);
    }


    function getCreatorProjects(address _creator)
        external
        view
        returns (uint256[] memory)
    {
        return creatorProjects[_creator];
    }


    function getInvestorProjects(address _investor)
        external
        view
        returns (uint256[] memory)
    {
        return investorProjects[_investor];
    }


    function getInvestorAmount(uint256 _projectId, address _investor)
        external
        view
        returns (uint256)
    {
        return investorAmounts[_projectId][_investor];
    }


    function getTotalProjects()
        external
        view
        returns (uint256)
    {
        return nextProjectId;
    }


    function canWithdrawFunds(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (bool)
    {
        Project storage project = projects[_projectId];
        return project.status == ProjectStatus.Successful && !project.fundsWithdrawn;
    }


    function canRequestRefund(uint256 _projectId, address _investor)
        external
        view
        projectExists(_projectId)
        returns (bool)
    {
        Project storage project = projects[_projectId];


        bool isRefundableStatus = project.status == ProjectStatus.Failed ||
                                 project.status == ProjectStatus.Cancelled ||
                                 (project.status == ProjectStatus.Active &&
                                  block.timestamp > project.deadline &&
                                  project.currentAmount < project.targetAmount);

        return isRefundableStatus && investorAmounts[_projectId][_investor] > 0;
    }
}
