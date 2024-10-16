import Result "mo:base/Result";
import Node "mo:devefi/node";
import Neuron "./neuron";
import ICRC55 "mo:devefi/ICRC55";
import Debug "mo:base/Debug";

module {

    public type CreateRequest = {
        #nns_neuron : Neuron.CreateRequest;
    };

    public type Mem = {
        #nns_neuron : Neuron.Mem;
    };

    public type Shared = {
        #nns_neuron : Neuron.Shared;
    };

    public type ModifyRequest = {
        #nns_neuron : Neuron.ModifyRequest;
    };

    public func toShared(node : Mem) : Shared {
        switch (node) {
            case (#nns_neuron(t)) #nns_neuron(Neuron.toShared(t));
        };
    };

    public func getDefaults(id : Text, all_ledgers : [ICRC55.SupportedLedger]) : CreateRequest {
        switch (id) {
            case ("nns_neuron") #nns_neuron(Neuron.defaults(all_ledgers));
            case (_) Debug.trap("Unknown variant");
        };
    };

    public func authorAccount(node : Mem) : ICRC55.Account {
        switch (node) {
            case (#nns_neuron(_)) Neuron.authorAccount();
        };
    };

    public func sourceMap(id : Node.NodeId, custom : Mem, thiscan : Principal, sourcesProvided : [ICRC55.Endpoint]) : Result.Result<[ICRC55.Endpoint], Text> {
        switch (custom) {
            case (#nns_neuron(t)) Neuron.request2Sources(t, id, thiscan, sourcesProvided);
        };
    };

    public func destinationMap(custom : Mem, destinationsProvided : [ICRC55.DestinationEndpoint]) : Result.Result<[ICRC55.DestinationEndpoint], Text> {
        switch (custom) {
            case (#nns_neuron(t)) Neuron.request2Destinations(t, destinationsProvided);
        };
    };

    public func createRequest2Mem(req : CreateRequest) : Mem {
        switch (req) {
            case (#nns_neuron(t)) #nns_neuron(Neuron.createRequest2Mem(t));
        };
    };

    public func modifyRequestMut(custom : Mem, creq : ModifyRequest) : Result.Result<(), Text> {
        switch (custom, creq) {
            case (#nns_neuron(t), #nns_neuron(r)) Neuron.modifyRequestMut(t, r);
            case (_) Debug.trap("You need to provide same id-variant");
        };
    };

    public func nodeMeta(custom : Mem, all_ledgers : [ICRC55.SupportedLedger]) : ICRC55.NodeMeta {
        switch (custom) {
            case (#nns_neuron(_)) Neuron.meta(all_ledgers);
        };
    };

    public func nodeBilling(custom : Mem) : ICRC55.Billing {
        switch (custom) {
            case (#nns_neuron(_t)) Neuron.billing();
        };
    };

    public func meta(all_ledgers : [ICRC55.SupportedLedger]) : [ICRC55.NodeMeta] {
        [
            Neuron.meta(all_ledgers),
        ];
    };
};
