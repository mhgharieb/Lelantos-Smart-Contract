pragma solidity ^0.4.0;

contract Lelatos {

    //State Machine
    enum States {Init, Created, Ordered, Accepted, Received, Next, Verified}

    //Variables
    States public state;
    uint public maxHopFee;
    address customer;
    address merchant;
    uint public pID;
    uint public price;
    bytes public nextLabel;
    bytes32[] trackingComm;
    bytes32 public commitment;
    uint expirationTime;
    uint maxDelFee;
    uint8 index;
    address currentHop;
    uint currentHopFee;
    bytes public mask;

    //Checks as Modifiers
    modifier checkState(States _state) {
        if (state != _state) throw;
        _;
    }

    modifier CheckCustomer() {
        if (customer != msg.sender) throw;
        _;
    }

    modifier CheckMerchant() {
        if (merchant != msg.sender) throw;
        _;
    }

    //Events
    event NewOrder(address merchant, uint pID, uint price, bytes label0, bytes nextLabel);
    event NewAccept(address merchant, uint pID);
    event NewReceiver(address currentHop);
    event NextHop(bytes mask, bytes nextLabel);
    event Pickup(States state);

    function Lelatos(uint _maxHopFee) {
        maxHopFee = _maxHopFee;
        state = States.Init;
        index = 0;
    }

    function create(bytes32 _commitment, bytes32[] _trackingComm) checkState(States.Init) {
        customer = msg.sender;
        state =  States.Created;
        commitment = _commitment;
        uint nHop = _trackingComm.length;
        for (uint i; i < nHop; i++) trackingComm.push(_trackingComm[i]);
        maxDelFee = nHop * maxHopFee;
    }

    function order(address _merchant, uint _pID, uint _price, bytes label0, bytes _nextLabel, uint validityTime) payable CheckCustomer checkState(States.Created) {
        if (_price + maxDelFee > msg.value) throw;
        merchant = _merchant;
        pID = _pID;
        price = _price;
        nextLabel = _nextLabel;
        expirationTime = now + validityTime;
        state = States.Ordered;
        NewOrder(merchant, pID, price, label0, nextLabel);
    }

    function accept(uint _pID) CheckMerchant checkState(States.Ordered) {
        if (pID != _pID) throw;
        currentHop = merchant;
        currentHopFee = price;
        state = States.Accepted;
        NewAccept(merchant, pID);
    }

    function receive(bytes trackingNum, uint _fee) {
        if (state != States.Accepted && state != States.Next) throw;
        if (trackingComm[index] != sha3(trackingNum)) throw;
        if (_fee > maxHopFee) throw;
        if (!currentHop.send(currentHopFee)) throw;
        currentHop = msg.sender;
        currentHopFee = _fee;
        state = States.Received;
        NewReceiver(currentHop);
    }

    function next(bytes _mask, bytes _nextLabel) CheckCustomer checkState(States.Received) {
        index++;
        mask = _mask;
        nextLabel = _nextLabel;
        state = States.Next;
        NextHop(mask, nextLabel);
    }

    function pickup(bytes secret) checkState(States.Received) {
        if (currentHop != msg.sender) throw;
        if (commitment != sha3(secret)) throw;
        if (!currentHop.send(currentHopFee)) throw;
        state = States.Verified;
        Pickup(state);
        selfdestruct(customer);
    }

    function withdraw() CheckCustomer checkState(States.Ordered) {
        if (now < expirationTime) throw;
        selfdestruct(customer);
    }
}
