pragma solidity ^0.4.13;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/SupplyChain.sol";

contract TestSupplyChain {
    uint public initialBalance = 5 ether;

    function testAddItemCreation() public {
        SupplyChain sC = new SupplyChain();
        ChainProxy seller = new ChainProxy(address(sC));

        seller.addItem("Item 1", .5 ether);

        uint expectedCount = 1;
        uint actualSkuCount = sC.skuCount();

        // verify the sku count is udpated accordingly
        Assert.equal(actualSkuCount, expectedCount, "We should have only one item in the items map");
    }

    // buy
    // test for failure if user does not send enough funds
    function testBuyItemFail() public {
        SupplyChain sC = new SupplyChain();
        ChainProxy seller = new ChainProxy(address(sC));
        ChainProxy buyer = new ChainProxy(address(sC));

        seller.addItem("Item 1", .5 ether);
        address(buyer).transfer(.1 ether);
        bool returnBuyValue = buyer.buyItem(0, .1 ether);

        Assert.isFalse(returnBuyValue, "buyer can still by an item even when the amount sent is smaller than a price");
    }

    // can't buy something that has already been purchased
    function testBuyItemWhichWasSold() public {
        SupplyChain sC = new SupplyChain();
        ChainProxy seller = new ChainProxy(address(sC));
        ChainProxy buyer = new ChainProxy(address(sC));
        ChainProxy buyer2 = new ChainProxy(address(sC));

        seller.addItem("Item 1", .5 ether);
        address(buyer).transfer(.5 ether);
        address(buyer2).transfer(1 ether);

        bool returnBuyValue = buyer.buyItem(0, .5 ether);
        Assert.isTrue(returnBuyValue, "buyItem() function threw an exception");
        (,,, uint _state,,) = sC.fetchItem(0);
        Assert.equal(_state, uint(SupplyChain.State.Sold), "State is wrong");

        returnBuyValue = buyer2.buyItem(0, .5 ether);
        Assert.isFalse(returnBuyValue, "can't purchase an item that has already been sold");
    }

    // shipItem
    // test for calls that are made by not the seller
    function testShipItem() public {
        SupplyChain sC = new SupplyChain();
        ChainProxy seller = new ChainProxy(address(sC));
        ChainProxy buyer = new ChainProxy(address(sC));

        seller.addItem("item 1", 0.01 ether);
        address(buyer).transfer(1 ether);
        buyer.buyItem(0, 0.01 ether);

        (,,, uint _state1,,) = sC.fetchItem(0);
        Assert.equal(_state1, uint(SupplyChain.State.Sold), "item not sold");

        seller.shipItem(0);
        (,,, uint _state2,,) = sC.fetchItem(0);
        Assert.equal(_state2, uint(SupplyChain.State.Shipped), "item not shipped");
    }

    // test for trying to ship an item that is not marked Sold
    function testShipItemNotSold() public {
        SupplyChain sC = new SupplyChain();
        ChainProxy seller = new ChainProxy(address(sC));

        seller.addItem("item 1", .5 ether);
        (,,, uint _state1,,) = sC.fetchItem(0);
        
        Assert.equal(_state1, uint(SupplyChain.State.ForSale), "State should be set to FroSale");

        bool executionResult = address(sC).call(abi.encodeWithSignature("shipItem(uint256)"), 0);
        Assert.isFalse(executionResult, "shipItem should fail since the item hasn't been sold yet");

        (,,, uint _state2,,) = sC.fetchItem(0);
        Assert.notEqual(_state2, uint(SupplyChain.State.Shipped), "item has not been shipped");
    }

    // receiveItem

    // test calling the function on an item not marked Shipped
    function testReceiveItemNotShipped() public {
        SupplyChain sC = new SupplyChain();
        ChainProxy seller = new ChainProxy(address(sC));
        ChainProxy buyer = new ChainProxy(address(sC));

        seller.addItem("item 1", 0.5 ether);
        address(buyer).transfer(1 ether);

        buyer.buyItem(0, .5 ether);

        bool executionResult = address(sC).call(abi.encodeWithSignature("receiveItem(uint256)"), 0);
        Assert.isFalse(executionResult, "Can't receive an item that hasn't been shipped");

        (,,, uint _state2,,) = sC.fetchItem(0);
        Assert.notEqual(_state2, uint(SupplyChain.State.Received), "item has not been Received");
    }

    // test calling the function from an address that is not the buyer
    function testReceiveItemNotByBuyer() public {
        SupplyChain sC = new SupplyChain();
        ChainProxy seller = new ChainProxy(address(sC));
        ChainProxy buyer = new ChainProxy(address(sC));
        ChainProxy maliciousPerson = new ChainProxy(address(sC));

        seller.addItem("item 1", 0.5 ether);
        address(buyer).transfer(1 ether);

        buyer.buyItem(0, .5 ether);

        seller.shipItem(0);

        bool executionResult = address(maliciousPerson).call(abi.encodeWithSignature("receiveItem(uint256)"), 0);
        Assert.isFalse(executionResult, "Can't receive an item  by someone other than the buyer");

        (,,, uint _state2,,) = sC.fetchItem(0);
        Assert.notEqual(_state2, uint(SupplyChain.State.Received), "State should not be Received");
    }

    function() public payable {}
}

contract ChainProxy {
    SupplyChain public sC;

    constructor(address _supplyChainAddress) public {
        sC = SupplyChain(_supplyChainAddress);
    }

    function addItem(string _name, uint _price) public {
        sC.addItem(_name, _price);
    }

    function buyItem(uint _sku, uint _price) public payable returns(bool) {
        return address(sC).call.value(_price)(abi.encodeWithSignature("buyItem(uint256)"), _sku);
    }

    function shipItem(uint _sku) public {
        sC.shipItem(_sku);
    }

    function receiveItem(uint _sku) public {
        sC.receiveItem(_sku);
    }

    function() public payable {}
}
