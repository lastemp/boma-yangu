import { ethers } from "hardhat";
import { expect } from "chai";
import { AffordableHousingProgram } from "../typechain-types";

describe("AffordableHousingProgram", function () {
  let affordableHousingProgram: AffordableHousingProgram;
  let admin: any;
  let member1: any;

  beforeEach(async function () {
    [admin, member1] = await ethers.getSigners();

    const AffordableHousingProgram = await ethers.getContractFactory("AffordableHousingProgram");
    affordableHousingProgram = await AffordableHousingProgram.deploy();
    await affordableHousingProgram.deployed();
  });

  it("should register a new member", async function () {
    const nationalIdentityNumber = ethers.utils.formatBytes32String("1234567890");
    const spouseNationalIdentityNumber = ethers.utils.formatBytes32String("0987654321");

    await affordableHousingProgram
      .connect(member1)
      .registerNewMember(nationalIdentityNumber, spouseNationalIdentityNumber, true);

    const memberData = await affordableHousingProgram.housingProgramData.members(member1.address);
    expect(memberData.registered).to.be.true;
    expect(memberData.married).to.be.true;
    expect(memberData.owner).to.equal(member1.address);
  });

  it("should fail to register a member with missing National Identity Number", async function () {
    const spouseNationalIdentityNumber = ethers.utils.formatBytes32String("0987654321");

    await expect(
      affordableHousingProgram
        .connect(member1)
        .registerNewMember("0x", spouseNationalIdentityNumber, true)
    ).to.be.revertedWith("National Identity Number has invalid value.");
  });

  it("should register a new housing unit", async function () {
    const projectReferenceNumber = ethers.utils.formatBytes32String("project1");
    const referenceNumber = ethers.utils.formatBytes32String("unit1");
    const unitType = 1; // e.g., TwoBedroom
    const totalUnitCost = ethers.utils.parseEther("100");
    const deposit = ethers.utils.parseEther("10");

    await affordableHousingProgram
      .connect(admin)
      .registerNewProject(projectReferenceNumber, false);

    await affordableHousingProgram
      .connect(admin)
      .registerNewHousingUnit(projectReferenceNumber, referenceNumber, unitType, totalUnitCost, deposit);

    const housingUnit = await affordableHousingProgram.housingProgramData.housingUnits(referenceNumber);
    expect(housingUnit.initialised).to.be.true;
    expect(housingUnit.unitType).to.equal(unitType);
    expect(housingUnit.totalUnitCost).to.equal(totalUnitCost);
  });

  it("should allow a member to deposit funds", async function () {
    const nationalIdentityNumber = ethers.utils.formatBytes32String("1234567890");

    await affordableHousingProgram
      .connect(member1)
      .registerNewMember(nationalIdentityNumber, "0x", false);

    await affordableHousingProgram.connect(member1).depositFunds({ value: ethers.utils.parseEther("5") });
    const memberBalance = await affordableHousingProgram.getMemberBalance(member1.address);
    expect(memberBalance).to.equal(ethers.utils.parseEther("5"));
  });

  it("should allocate a housing unit to a registered member with sufficient deposit", async function () {
    const nationalIdentityNumber = ethers.utils.formatBytes32String("1234567890");
    const referenceNumber = ethers.utils.formatBytes32String("unit1");
    const projectReferenceNumber = ethers.utils.formatBytes32String("project1");
    const unitType = 1;
    const totalUnitCost = ethers.utils.parseEther("100");
    const deposit = ethers.utils.parseEther("10");

    await affordableHousingProgram
      .connect(member1)
      .registerNewMember(nationalIdentityNumber, "0x", false);

    await affordableHousingProgram.connect(member1).depositFunds({ value: deposit });

    await affordableHousingProgram
      .connect(admin)
      .registerNewProject(projectReferenceNumber, false);
    await affordableHousingProgram
      .connect(admin)
      .registerNewHousingUnit(projectReferenceNumber, referenceNumber, unitType, totalUnitCost, deposit);

    await affordableHousingProgram.connect(admin).allocateHousingUnit(member1.address, referenceNumber);

    const memberData = await affordableHousingProgram.housingProgramData.members(member1.address);
    const housingUnit = await affordableHousingProgram.housingProgramData.housingUnits(referenceNumber);

    expect(memberData.housingAllocated).to.be.true;
    expect(housingUnit.housingAllocated).to.be.true;
    expect(housingUnit.owner).to.equal(member1.address);
  });
});
