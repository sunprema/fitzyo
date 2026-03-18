<script>
  let count = $state(0);
  let { number, live } = $props();

  const incrementCounter = () => {
    count++;
  };

  const incrementNumber = () => {
    live.pushEvent("set_number", { number: number + 1 }, () => {});
  };
</script>

<h1>Inside Svelte - {count} - number is {number}</h1>
<button onclick={incrementCounter}> Incr Counter</button>
<button onclick={incrementNumber}> Incr Number property</button>

<style>
  button {
    background-color: salmon;
  }
</style>
