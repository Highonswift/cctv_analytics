import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import PersonDetection from "./pages/PersonDetection.jsx";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Navigate to="/persondetection" replace />} />
        <Route path="/persondetection" element={<PersonDetection />} />
      </Routes>
    </BrowserRouter>
  );
}
