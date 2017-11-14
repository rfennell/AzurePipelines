//-----------------------------------------------------------------------
// <copyright file="FileWithLocalFunction.cs" company="Dummy Company">
//     Copyright (c) Dummy Company. All rights reserved.
// </copyright>
// <summary>
//     A test file that is used in testing.
// </summary>
//-----------------------------------------------------------------------
namespace WindowsFormsApplication1
{
    using System;

    /// <summary>
    /// A test file.
    /// </summary>
    public static class FileWithLocalFunction
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        public static void Main()
        {
            Add(10, 5);

            int Add(int x, int y)
            {
                return x + y;
            }
        }
    }
}
