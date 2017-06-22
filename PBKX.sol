pragma solidity ^0.4.2;

contract IToken {
  function balanceOf(address _address) constant returns (uint balance);
  function transfer(address _to, uint _value) returns (bool success);
}

contract PBKXToken is IToken {
    string public standard = 'PBKXToken 0.1';
    string public name = 'PBKXToken';
    string public symbol = 'PBKX';
	
	address owner;
	
	event Burn(address indexed from, uint256 value);
	
	modifier owneronly { if (msg.sender == owner) _; }
  
    function setOwner(address _owner) owneronly {
      owner = _owner;
    } 
	
    mapping (address => uint) balanceFor;
	address[] addressByIndex;

    function PBKXToken() {
        balanceFor[msg.sender] = 3000000;              // Give the creator all initial tokens
    }
	
	function balanceOf(address _address) constant returns (uint balance) {
		return balanceFor[_address];
	}
	
	function exchangeToIco(address _icoToken, uint exchangeRate) owneronly {
	    IToken icoToken = IToken(_icoToken);
		for (uint ai = 0; ai < addressByIndex.length; ai++) {
			address currentAddress = addressByIndex[ai];
			icoToken.transfer(currentAddress, balanceFor[currentAddress] * exchangeRate);
			balanceFor[currentAddress] = 0;
		}
	}

    function transfer(address _to, uint _value) returns (bool success) {
        if (balanceFor[msg.sender] < _value) throw;           // Check if the sender has enough
        if (balanceFor[_to] + _value < balanceFor[_to]) throw; // Check for overflows
        balanceFor[msg.sender] -= _value;                     // Subtract from the sender
		if (balanceFor[_to] == 0) {
		    addressByIndex.length++;
			addressByIndex[addressByIndex.length-1] = _to;
		}
        balanceFor[_to] += _value;                            // Add the same to the recipient
        return true;
    }
	
	function burn(uint256 _value) returns (bool success) {
        if (balanceFor[msg.sender] < _value) throw;            // Check if the sender has enough
        balanceFor[msg.sender] -= _value;                      // Subtract from the sender
        Burn(msg.sender, _value);
        return true;
    }
	
	/* This unnamed function is called whenever someone tries to send ether to it */
    function () {
        throw;     // Prevents accidental sending of ether
    }
}