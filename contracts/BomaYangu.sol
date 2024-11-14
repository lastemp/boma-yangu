// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

contract Member {
    struct MemberData {
      bytes nationalIdentityNumber;
      bytes spouseNationalIdentityNumber;
      bool married;
      bool registered;
      bool depositAchieved;
      bool housingAllocated;
      address owner;
    }

    MemberData memberData;

    function registerMember(bytes memory nationalIdentityNumber_, bytes memory spouseNationalIdentityNumber_, bool married_) internal returns (MemberData memory) {
        require(nationalIdentityNumber_.length > 0, "National Identity Number has invalid value.");
        require(((!married_ && spouseNationalIdentityNumber_.length == 0) || (married_ && spouseNationalIdentityNumber_.length > 0)), "Spouse National Identity Number has invalid value.");
        memberData.nationalIdentityNumber = nationalIdentityNumber_;
        memberData.spouseNationalIdentityNumber = spouseNationalIdentityNumber_;
        memberData.married = married_;
        memberData.registered = true;
        memberData.owner = msg.sender;

        return memberData;
    }
}

contract HousingUnit {
    enum HousingUnitType {OneBedroom, TwoBedroom, ThreeBedroom}
    struct HousingUnitData {
      bytes referenceNumber;
      HousingUnitType unitType;
      uint256 totalUnitCost;
      uint256 deposit;
      uint256 totalPayments;
      bool housingAllocated;
      bool initialised;
      address owner;
      address admin;
    }

    HousingUnitData housingUnitData;

    // Constructor code is only run when the contract
    // is created
    constructor() {
        housingUnitData.admin = msg.sender;
    }

    function registerHousingUnit(bytes memory referenceNumber_, HousingUnitType unitType_, uint256 totalUnitCost_, uint256 deposit_) internal returns (HousingUnitData memory) {
        require(msg.sender == housingUnitData.admin, "Signer address is not authorised to make changes.");
        require(referenceNumber_.length > 0, "Reference Number has invalid value.");
        require(totalUnitCost_ > 0, "Total Unit Cost has invalid value.");
        require(deposit_ > 0, "Deposit has invalid value.");
        housingUnitData.referenceNumber = referenceNumber_;
        housingUnitData.unitType = unitType_;
        housingUnitData.totalUnitCost = totalUnitCost_;
        housingUnitData.deposit = deposit_;
        housingUnitData.initialised = true;

        return housingUnitData;
    }
}

contract Project {
    struct ProjectData {
      bytes referenceNumber;
      bytes[] batchHousingUnits;
      uint256 totalDeposit;
      uint256 totalPayments;
      bool completed;
      uint16 totalHousingUnits;
      uint16 totalAllocated;
      bool initialised;
      address admin;
    }

    ProjectData projectData;

    // Constructor code is only run when the contract
    // is created
    constructor() {
        projectData.admin = msg.sender;
    }

    function registerProject(bytes memory referenceNumber_, bool completed_) internal returns (ProjectData storage) {
        require(msg.sender == projectData.admin, "Signer address is not authorised to make changes.");
        require(referenceNumber_.length > 0, "Reference Number has invalid value.");
        projectData.referenceNumber = referenceNumber_;
        projectData.completed = completed_;
        projectData.initialised = true;
        return projectData;
    }

    function compareBytes(bytes memory a, bytes memory b) private pure returns (bool) {
        return keccak256(a) == keccak256(b);
    }

    function updateProject(bytes memory referenceNumber_, bytes memory housingUnitReferenceNumber_) internal {
        require(msg.sender == projectData.admin, "Signer address is not authorised to make changes.");
        require(referenceNumber_.length > 0, "Reference Number has invalid value.");
        require(housingUnitReferenceNumber_.length > 0, "Housing unit reference Number has invalid value.");
        require(compareBytes(projectData.referenceNumber, referenceNumber_), "Reference Number cannot be verified.");
        projectData.batchHousingUnits.push(housingUnitReferenceNumber_);
        projectData.totalHousingUnits += 1;
    }
}

contract Vault {
    // Mapping to store each member's deposited balance
    mapping(address => uint256) public balances;

    // Address of the contract owner (admin)
    address public admin;

    // Event to log deposits
    event Deposit(address indexed member, uint256 amount);

    // Event to log withdrawals
    event Withdraw(address indexed admin, uint256 amount);

    // Constructor to set the contract admin
    constructor() {
        admin = msg.sender;
    }

    // Modifier to restrict access to admin-only functions
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can call this function");
        _;
    }

    // Function for members to deposit funds into the vault
    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than zero");

        // Update the sender's balance
        balances[msg.sender] += msg.value;

        // Emit deposit event
        emit Deposit(msg.sender, msg.value);
    }

    // Function to check the vault's total balance, restricted to the admin only
    function getVaultBalance() external onlyAdmin view returns (uint256) {
        return address(this).balance;
    }

    // Function to withdraw funds, restricted to the admin only
    function withdraw(uint256 amount_) external onlyAdmin {
        require(amount_ > 0, "Withdraw amount must be greater than zero");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        require(balance > amount_, "Insufficient funds");

        // Transfer the withdrawal amount to the admin
        payable(admin).transfer(amount_);

        // Emit withdraw event
        emit Withdraw(admin, amount_);
    }

    // Function to check an individual member's balance
    function getMemberBalance(address _member) external view returns (uint256) {
        return balances[_member];
    }
}

contract AffordableHousingProgram is Member, HousingUnit, Project, Vault {
    struct HousingProgramData {
      mapping(address => MemberData) members;
      mapping(bytes => HousingUnitData) housingUnits;
      mapping(bytes => ProjectData) projects;
      uint256 totalDeposit;
      uint256 totalPayments;
      uint16 totalProjects;
      uint16 totalCompleted;
      uint16 totalAllocated;
      address admin;
    }

    HousingProgramData housingProgramData;

    // Constructor code is only run when the contract
    // is created
    constructor() {
        housingProgramData.admin = msg.sender;
    }

    function registerNewMember(bytes memory nationalIdentityNumber_, bytes memory spouseNationalIdentityNumber_, bool married_) external {
        require(nationalIdentityNumber_.length > 0, "National Identity Number has invalid value.");
        require(((!married_ && spouseNationalIdentityNumber_.length == 0) || (married_ && spouseNationalIdentityNumber_.length > 0)), "Spouse National Identity Number has invalid value.");

        // Check if member is already registered
        MemberData memory memberData = housingProgramData.members[msg.sender];
        require(!memberData.registered, "Member is already registered");

        // call registerMember in contract Member
        MemberData memory memberData_ = registerMember(nationalIdentityNumber_, spouseNationalIdentityNumber_, married_);
        housingProgramData.members[msg.sender] = memberData_;
    }

    function registerNewHousingUnit(bytes memory projectReferenceNumber_, bytes memory referenceNumber_, HousingUnitType unitType_, uint256 totalUnitCost_, uint256 deposit_) external {
        require(msg.sender == housingUnitData.admin, "Signer address is not authorised to make changes.");
        require(referenceNumber_.length > 0, "Reference Number has invalid value.");
        require(projectReferenceNumber_.length > 0, "Project Reference Number has invalid value.");
        require(totalUnitCost_ > 0, "Total Unit Cost has invalid value.");
        require(deposit_ > 0, "Deposit has invalid value.");

        // Check if housing unit is already registered
        HousingUnitData memory housingUnitData = housingProgramData.housingUnits[referenceNumber_];
        require(!housingUnitData.initialised, "Housing unit is already registered");
        
        HousingUnitData memory housingUnitData_ = registerHousingUnit(referenceNumber_, unitType_, totalUnitCost_, deposit_);
        housingProgramData.housingUnits[referenceNumber_] = housingUnitData_;

        updateProject(projectReferenceNumber_, referenceNumber_);
    }

    function registerNewProject(bytes memory referenceNumber_, bool completed_) external {
        require(msg.sender == projectData.admin, "Signer address is not authorised to make changes.");
        require(referenceNumber_.length > 0, "Reference Number has invalid value.");

        // Check if project is already registered
        ProjectData storage projectData = housingProgramData.projects[referenceNumber_];
        require(!projectData.initialised, "Project is already registered");
        
        ProjectData storage projectData_ = registerProject(referenceNumber_, completed_);
        housingProgramData.projects[referenceNumber_] = projectData_;
    }

    function depositFunds(bytes memory referenceNumber_) external payable {
        require(msg.value > 0, "Amount must be greater than zero");
        require(referenceNumber_.length > 0, "Reference Number has invalid value.");
        MemberData storage memberData = housingProgramData.members[msg.sender];
        require(memberData.registered, "Member is not registered");
        HousingUnitData memory housingUnitData = housingProgramData.housingUnits[referenceNumber_];
        require(housingUnitData.initialised, "Housing unit not registered");
        require(msg.value == housingUnitData.deposit, "Amount must be equal to housing unit deposit amount");

        deposit();
        memberData.depositAchieved = true;
        
    }
    
    function allocateHousingUnit(address member_, bytes memory referenceNumber_) external {
        require(msg.sender == admin, "Only the admin can call this function");
        require(msg.sender != member_, "Admin cannot be specified as a member");
        require(referenceNumber_.length > 0, "Reference Number has invalid value.");

        MemberData storage memberData = housingProgramData.members[member_];

        require(memberData.registered, "Member is not registered");
        require(memberData.depositAchieved, "Member has not yet achieved the required deposit");
        require(!memberData.housingAllocated, "Member has previously been allocated a housing unit");

        HousingUnitData storage housingUnitData = housingProgramData.housingUnits[referenceNumber_];

        require(housingUnitData.initialised, "Housing unit not registered");
        memberData.housingAllocated = true;
        housingUnitData.owner = member_;
        housingUnitData.housingAllocated = true;
    }

    function getMemberData(address member_) external view returns (MemberData memory) {
        return housingProgramData.members[member_];
    }

    function getHousingUnitData(bytes memory referenceNumber_) external view returns (HousingUnitData memory) {
        return housingProgramData.housingUnits[referenceNumber_];
    }

}