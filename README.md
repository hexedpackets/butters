# Butters

<img src="https://vignette.wikia.nocookie.net/southpark/images/b/b8/Professor-chaos.png/revision/latest?cb=20180409101847" style="max-width:100%;" width="120">

Tooling for doing chaos engineering on a kubernetes cluster. Inspired by [blockade](https://github.com/worstcase/blockade/)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `butters` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:butters, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/butters](https://hexdocs.pm/butters).

## TODOS

- [x] Partition off individual kubelets from the master
- [ ] Bombard the kubernetes-api with requests
- [ ] Force resource exhaustion on an individual node
- [ ] Disconnect a node from the network for some time period and reconnect it
- [ ] Kill a node and monitor what happens to its workloads
- [x] slow/flaky network connections between master and nodes
- [ ] add anti-affinity for pod tags to avoid hurting sensitive applications
