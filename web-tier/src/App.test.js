import { render, screen } from "@testing-library/react";
import App from "./App";

test("renders application title", () => {
  render(<App />);

  expect(screen.getByText(/AWS 3-TIER WEB APP DEMO/i)).toBeInTheDocument();
});

test("renders Home menu", () => {
  render(<App />);

  expect(screen.getByText(/Home/i)).toBeInTheDocument();
});

test("renders DB Demo menu", () => {
  render(<App />);

  expect(screen.getByText(/DB Demo/i)).toBeInTheDocument();
});
