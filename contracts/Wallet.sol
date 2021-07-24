pragma solidity 0.8.0;
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Wallet {
  /// @title A multi-signature wallet that requires the approval of a certain number of owners to execute transactions.
  /// @author Eerina Haque
  /// @notice This wallet allows only for deposits and transfers. There is no interaction with external contracts or applications.
  using SafeMath for uint;

  uint contractBalance;
  address[] public owners;
  uint numOwners;
  mapping(address => bool) public isOwner;
  mapping(uint => mapping(address => bool)) isSigned;
  uint public sigsReq;

  struct Transaction {
    uint transactionIndex;
    address to;
    address from;
    uint value;
    uint numSigs;
    bool executed;
  }

  Transaction[] transactions;

  constructor(address[] memory _owners, uint _sigsRequired) {
    require(_sigsRequired > 0 && _sigsRequired <= _owners.length);
    sigsReq = _sigsRequired;
    owners = _owners;
    for (uint i = 0; i < _owners.length; i++) {
      address owner = _owners[i];
      require(owner != address(0), "invalid address");
      require(isOwner[owner] != true, "not a unique owner");
      isOwner[owner] = true;
    }
  }

  /* events */
  /// @notice Logs the value of funda deposited into the contract. It can be
  /// queried by the address of the account that deposited.
  /// @param _account The account that deposited funds.
  /// @param _value The value of the funds that were transacted.
  event Deposited(address indexed _account, uint _value);

  /// @notice Logs the index of an approved transaction. It can be queried by
  /// the address of the account that approved it.
  /// @param _account The account that approved the transaction.
  /// @param _transactionIndex The index of the transaction that was approved.
  event Signed(address indexed _account, uint _transactionIndex);

  /// @notice Logs the index of an executed transaction. It can be queried by
  /// the address of the account that executed it.
  /// @param _account The account that executed the transaction.
  /// @param _transactionIndex The index of the transaction that was executed.
  event Executed(uint indexed _account, uint _transactionIndex);

  /* modifiers */
  modifier onlyOwner {
    require(isOwner[msg.sender]);
    _;
  }

  /// @notice Allows any user to deposit funds into the contract.
  function deposit() public payable returns(bool _success) {
    contractBalance.add(msg.value);
    emit Deposited(msg.sender, msg.value);
    _success = true;
  }

  /// @notice Allows an owner to create a request for transferring funds out of
  /// the wallet.
  /// @param _to The address that the funds are being sent to.
  /// @param _value The value of the funds that are being transferred.
  function requestTransaction(address _to, address _from, uint _value) public onlyOwner {
    require(contractBalance >= _value, "not enough funds in the wallet to request transaction");
    transactions.push(Transaction({
      transactionIndex: transactions.length,
      to : _to,
      from: _from,
      value: _value,
      numSigs: 0,
      executed: false
    }));
  }

  /// @notice Allows an owner to approve a specified transaction. Automatically
  /// executes transaction if the required number of approvals are met.
  /// @param _transactionIndex The index of the transaction that is to be approved.
  function approveTransaction(uint _transactionIndex) public onlyOwner {
    require(_transactionIndex < transactions.length, "this transaction has not yet been requested");
    require(!isSigned[_transactionIndex][msg.sender], "user has already approved this transaction");
    require(!transactions[_transactionIndex].executed, "this transaction has already been executed");
    require(contractBalance >= transactions[_transactionIndex].value,
      "not enough funds in the wallet to approve transaction");

    isSigned[_transactionIndex][msg.sender] = true;
    transactions[_transactionIndex].numSigs++;

    emit Signed(msg.sender, _transactionIndex);

    if(transactions[_transactionIndex].numSigs > sigsReq) {
      uint transferValue = transactions[_transactionIndex].value;
      transactions[_transactionIndex].executed = true;
      contractBalance.sub(transferValue);
      (bool success,) = transactions[_transactionIndex].to.call{value: transferValue}("");
      emit Executed(msg.sender, _transactionIndex);
      assert(success);
    }
  }

  /// @notice Gives any user access to all of the transactions that have been requested.
  /// @return _transactions All of the transactions that have been requested in
  ///  this contract.
  function getTransactions() public view returns(Transaction[] memory _transactions) {
    _transactions = transactions;
  }

  function getBalance() public view returns(uint _balance) {
    _balance = contractBalance;
  }
}
